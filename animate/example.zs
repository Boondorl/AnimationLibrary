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
	private transient CVar svMod;
	private double prevMod;
	
	override void OnRegister()
	{
		svMod = CVar.GetCVar("us_modifier");
		prevMod = svMod.GetFloat();
	}
	
	override void WorldThingSpawned(WorldEvent e)
	{
		if (e.thing && ((e.thing.bIsMonster && e.thing.bShootable) || e.thing.player))
		{
			e.thing.GiveInventory("AnimMod", 1);
			let am = AnimMod(e.thing.FindInventory("AnimMod"));
			if (am)
			{
				if (!svMod)
					svMod = CVar.GetCVar("us_modifier");
				
				am.modifier = svMod.GetFloat();
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
	
	override void WorldTick()
	{
		if (!svMod)
			svMod = CVar.GetCVar("us_modifier");
		
		double modifier = svMod.GetFloat();
		if (!(modifier ~== prevMod))
			UpdateModifiers(modifier);
		
		prevMod = modifier;	
	}
	
	private void UpdateModifiers(double mod)
	{
		for (uint i = 0; i < mods.Size(); ++i)
		{
			let a = mods[i];
			if (!a)
				continue;
			
			a.modifier = mod;
			for (uint j = 0; j < a.anim.Count(); ++j)
			{
				if (a.anim.layers[j])
					a.anim.layers[j].ChangeModifier(a.modifier);
			}
		}
		
		console.printf("%.2fx speed", mod > 0 ? 1 / mod : 0);
	}
}