class AnimMod : Inventory
{
	const LAYER_MAIN = 0;

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
		+DONTBLAST
		+NOTONAUTOMAP
		+INVENTORY.UNDROPPABLE
	}
	
	override void PostBeginPlay() {}
	
	override void MarkPrecacheSounds() {}
	
	override void Tick() {}
	
	override void BeginPlay()
	{
		modifier = 1;
		prevStates.Push(null);
	}
	
	override void DoEffect()
	{
		if (!owner)
			return;
		
		AnimationLayer main;
		AnimationInfo ai;
		[main, ai] = anim.CreateLayer(owner, LAYER_MAIN);
		if (!main)
			return;
			
		if (CheckNewSequence(owner.curState, prevStates[0]))
			main.SetModifier(modifier);
		
		if (main.Modify())
			prevStates[0] = owner.curState;

		if (owner.bDestroyed)
			return;

		console.printf("%d", ai.Size());

		/*if (owner.player && owner.player.mo == owner)
		{
			anim.AddPSprites(owner, PSPF_ALL);
			for (uint i = 0; i < ai.Size(); ++i)
			{
				if (!ai.layers[i])
					continue;

				let psp = ai.layers[i].GetPSprite();
				if (!psp)
					continue;

				if (i >= prevStates.Size())
					prevStates.Push(null);

				if (CheckNewSequence(psp.curState, prevStates[i]))
					ai.layers[i].SetModifier(modifier);

				if (ai.layers[i].Modify() && psp)
					prevStates[i] = psp.curState;

				anim.AddPSprites(owner, PSPF_ALL);
			}
		}*/
	
		anim.CleanUpLayers();
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
	private double prevMod;
	
	override void OnRegister()
	{
		prevMod = us_modifier;
	}
	
	override void WorldThingSpawned(WorldEvent e)
	{
		if (e.thing && ((e.thing.bIsMonster && e.thing.bShootable) || e.thing.player))
		{
			e.thing.GiveInventory("AnimMod", 1);
			let am = AnimMod(e.thing.FindInventory("AnimMod"));
			if (am)
			{
				am.modifier = us_modifier;
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
		if (!(us_modifier ~== prevMod))
			UpdateModifiers(us_modifier);
		
		prevMod = us_modifier;	
	}
	
	private void UpdateModifiers(double mod)
	{
		for (uint i = 0; i < mods.Size(); ++i)
		{
			let a = mods[i];
			if (!a)
				continue;
			
			a.modifier = mod;
			for (uint j = 0; j < a.anim.ActorCount(); ++j)
			{
				for (uint k = 0; k < a.anim.actors[j].Size(); ++k)
				{
					if (a.anim.actors[j].layers[k])
						a.anim.actors[j].layers[k].ChangeModifier(a.modifier);
				}
			}
		}
		
		console.printf("%.2fx speed", mod > 0 ? 1 / mod : 0);
	}
}