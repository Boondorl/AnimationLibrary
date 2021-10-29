class AnimMod : Inventory
{
	private Array<State> prevStates;
	
	Animation anim;
	
	double modifier;
	
	Default
	{
		FloatBobPhase 0;
		Radius 0;
		Height 0;
		
		+SYNCHRONIZED
		+NOBLOCKMAP
		+NOSECTOR
		+INVENTORY.UNDROPPABLE
	}
	
	override void PostBeginPlay() {}
	
	override void MarkPrecacheSounds() {}
	
	override void Tick() {}
	
	override void BeginPlay()
	{
		modifier = 1;
	}
	
	// Custom loop that changes animations at all times
	override void DoEffect()
	{
		if (!owner)
			return;
			
		AnimationLayer main = anim.FindLayer(0);
		if (!main)
		{
			main = anim.CreateLayer(owner, 0);
			prevStates.Push(null);
		}
			
		if (CheckNewSequence(owner.curState, prevStates[0]))
			main.SetModifier(modifier);
			
		bool res = main.Modify();
		
		if (owner)
		{
			if (res)
				prevStates[0] = owner.curState;
		
			if (owner.player)
			{
				UpdatePSprites();
				
				for (uint i = 1; i < anim.Count(); ++i)
				{
					let layer = anim.layers[i];
					if (!layer || !layer.psp)
						continue;
						
					if (CheckNewSequence(layer.psp.curState, prevStates[i]))
						layer.SetModifier(modifier);
						
					if (layer.Modify() && layer.psp)
						prevStates[i] = layer.psp.CurState;
					
					UpdatePSprites();
				}
				
				RemovePSprites();
			}
		}
	}
	
	private void UpdatePSprites()
	{
		let pspr = owner.player.psprites;
		while (pspr)
		{
			if (!anim.FindLayer(pspr.id))
			{
				anim.CreateLayer(owner, pspr.id, pspr);
				prevStates.Push(null);
			}
			
			pspr = pspr.next;
		}
	}
	
	private void RemovePSprites()
	{
		for (uint i = 1; i < anim.Count(); ++i)
		{
			if (anim.layers[i] && !anim.layers[i].psp)
			{
				anim.RemoveLayer(anim.layers[i].id);
				prevStates.Delete(i--);
			}
		}
	}
	
	private bool CheckNewSequence(State cur, State prev)
	{
		if (!cur)
			return false;
			
		return !prev || (prev != cur && (prev.DistanceTo(cur) != 1 || prev.NextState != cur));
	}
}

class TestHandler : EventHandler
{
	private Array<AnimMod> mods;
	private double modifier;
	
	override void OnRegister()
	{
		modifier = 1;
	}
	
	override void WorldThingSpawned(WorldEvent e)
	{
		if (e.thing && ((e.thing.bIsMonster && e.thing.bShootable) || e.thing.player))
		{
			e.thing.GiveInventory("AnimMod", 1);
			let am = AnimMod(e.thing.FindInventory("AnimMod"));
			if (am)
			{
				am.modifier = modifier;
				mods.Push(am);
			}
		}
	}
	
	override void WorldThingDestroyed(WorldEvent e)
	{
		let am = AnimMod(e.thing);
		if (am)
			mods.Delete(mods.Find(am));
	}
	
	override void NetworkProcess(ConsoleEvent e)
	{
		if (e.Player != net_arbitrator)
			return;
		
		if (e.Name ~== "increase")
		{
			if (modifier > 1)
				modifier -= 0.5;
			else if (modifier > 0.25)
				modifier -= 0.2;
			
			UpdateModifiers();
			
			console.printf("Animation modifier: %.2f", modifier);
		}
		else if (e.Name ~== "decrease")
		{
			if (modifier < 1)
				modifier += 0.2;
			else if (modifier < 3)
				modifier += 0.5;
			
			UpdateModifiers();
			
			console.printf("Animation modifier: %.2f", modifier);
		}
	}
	
	private void UpdateModifiers()
	{
		for (uint i = 0; i < mods.Size(); ++i)
		{
			let a = mods[i];
			if (!a)
				continue;
			
			a.modifier = modifier;
			for (uint j = 0; j < a.anim.Count(); ++j)
			{
				if (a.anim.layers[j])
					a.anim.layers[j].ChangeModifier(a.modifier);
			}
		}
	}
}