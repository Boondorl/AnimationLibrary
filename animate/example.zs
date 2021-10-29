class AnimMod : Inventory
{
	private Array<State> prevStates;
	
	Animation anim;
	
	double modifier;
	
	Default
	{
		+NOBLOCKMAP
		+NOSECTOR
		+INVENTORY.UNDROPPABLE
	}
	
	override void BeginPlay()
	{
		super.BeginPlay();
		
		modifier = 1;
	}
	
	override void Tick() {}
	
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
	override void WorldThingSpawned(WorldEvent e)
	{
		if (e.thing && ((e.thing.bIsMonster && e.thing.bShootable) || e.thing.player))
			e.thing.GiveInventory("AnimMod", 1);
	}
	
	override void NetworkProcess(ConsoleEvent e)
	{
		if (e.Player != net_arbitrator)
			return;
		
		if (e.Name ~== "increase")
		{
			ThinkerIterator it = ThinkerIterator.Create("AnimMod", Thinker.STAT_INVENTORY);
			AnimMod anim;
			
			double mod;
			while (anim = AnimMod(it.Next()))
			{
				if (!anim)
					continue;
				
				if (anim.modifier > 1)
					anim.modifier -= 0.5;
				else if (anim.modifier > 0.25)
					anim.modifier -= 0.2;
				
				mod = anim.modifier;
				
				UpdateModifiers(anim);
			}
			
			Console.printf("Animation modifier: %.2f", mod);
		}
		else if (e.Name ~== "decrease")
		{
			ThinkerIterator it = ThinkerIterator.Create("AnimMod", Thinker.STAT_INVENTORY);
			AnimMod anim;
			
			double mod;
			while (anim = AnimMod(it.Next()))
			{
				if (!anim)
					continue;
					
				if (anim.modifier < 1)
					anim.modifier += 0.2;
				else if (anim.modifier < 3)
					anim.modifier += 0.5;
				
				mod = anim.modifier;
				
				UpdateModifiers(anim);
			}
			
			Console.printf("Animation modifier: %.2f", mod);
		}
	}
	
	private void UpdateModifiers(AnimMod a)
	{
		if (!a)
			return;
			
		for (uint i = 0; i < a.anim.Count(); ++i)
		{
			if (a.anim.layers[i])
				a.anim.layers[i].ChangeModifier(a.modifier);
		}
	}
}