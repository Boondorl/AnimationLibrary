class AnimationLayer play
{
	private int id;
	private Actor owner;
	private int pspID;
	
	private double modifier;
	private State start;
	private int tics;
	private bool bSetModifier;
	
	private int timer;
	private double roundUp;
	
	void Reset()
	{
		modifier = 1;
		start = null;
		tics = 0;
		
		timer = 0;
		roundUp = 0;
	}
	
	void SetModifier(double mod, State s = null)
	{
		Reset();

		if (!owner)
			return;
		
		State thisState = s;
		if (!thisState)
		{
			if (pspID)
			{
				let psp = GetPSprite();
				if (psp)
					thisState = psp.CurState;
			}
			else
				thisState = owner.CurState;
		}
			
		if (!thisState)
			return;
		
		if (mod < 0)
			mod = 0;
		
		modifier = mod;
		start = thisState;
		tics = Animation.GetSequenceLength(thisState);
		bSetModifier = true;
	}
	
	void ChangeModifier(double mod)
	{
		if (mod < 0)
			mod = 0;
			
		modifier = mod;
		
		timer = 0;
		roundUp = 0;
	}
	
	bool Modify()
	{
		bSetModifier = false;

		if (!owner || owner.IsFrozen())
			return false;

		if (modifier ~== 1)
			return true;
			
		State thisState;
		PSprite psp;
		if (pspID)
		{
			psp = GetPSprite();
			if (psp)
				thisState = psp.CurState;
		}
		else
			thisState = owner.CurState;
		
		if (!thisState || thisState.tics == -1)
			return false;
		
		if (--timer > 0)
			return true;
			
		double interval;
		if (modifier > 1)
			interval = modifier;
		else
		{
			int ticsLeft = round(tics * (1 - modifier));
			if (ticsLeft > 0)
				interval = double(tics-ticsLeft) / ticsLeft;
		}
	
		int realInterval = ceil(interval);
		if (modifier > 1)
		{
			int trunc = int(interval);
			if (trunc < interval)
			{
				roundUp += (interval-trunc);
				
				if (roundUp < 1)
					realInterval = trunc;
				else
					--roundUp;
			}
		}
		
		timer = realInterval;
		
		int cap = Animation.GetSequenceLength(thisState);
		int mod = 1;
		if (modifier ~== 0)
			mod = cap;
		else
		{
			if (modifier > 1)
				mod = realInterval - 1;	
			else if (interval < 1)
			{
				mod = ceil(1/interval);
				if (mod > cap)
					mod = cap;
			}
		}
		
		if (modifier > 1)
		{
			if (pspID)
				psp.tics += mod;
			else
				owner.tics += mod;
		}
		else
		{
			if (pspID)
			{
				if (psp.tics > mod)
					psp.tics -= mod;
				else
				{
					int tempMod = mod;
					do
					{
						int tempTics = min(tempMod, psp.tics);
						tempMod -= tempTics;
						psp.tics -= tempTics;
						if (psp.tics <= 0)
						{
							State prev = psp.CurState;
							psp.SetState(psp.CurState.NextState);
							if (!psp || !ContinueAnimating(psp.CurState, prev))
							{
								if (!bSetModifier)
									Reset();
								return false;
							}
						}
					} while (tempMod > 0);
				}
			}
			else
			{
				if (owner.tics > mod)
					owner.tics -= mod;
				else
				{
					int tempMod = mod;
					do
					{
						int tempTics = min(tempMod, owner.tics);
						tempMod -= tempTics;
						owner.tics -= tempTics;
						if (owner.tics <= 0)
						{
							State prev = owner.CurState;
							if (!owner.SetState(owner.CurState.NextState) || !ContinueAnimating(owner.CurState, prev))
							{
								if (!bSetModifier)
									Reset();
								return false;
							}
						}
					} while (tempMod > 0);
				}
			}
		}
		
		return true;
	}
	
	private bool ContinueAnimating(State current, State prev)
	{
		return current && current.tics != -1 && current != start && (!prev || prev.DistanceTo(current) == 1);
	}

	clearscope bool Matches(int i) const
	{
		return id == i;
	}

	clearscope PSprite GetPSprite() const
	{
		if (!pspID || !owner || !owner.player || owner.player.mo != owner)
			return null;

		return owner.player.FindPSprite(pspID);
	}

	static AnimationLayer Create(Actor owner, int id, int pspID = 0)
	{
		if (!owner)
			return null;

		let layer = new("AnimationLayer");

		layer.owner = owner;
		layer.id = id;
		layer.pspID = pspID;

		layer.Reset();

		return layer;
	}
}

enum EPSpriteFlags
{
	PSPF_NONE = 0,
	PSPF_WEAPONS = 1,
	PSPF_CUSTOM_INVENTORY = 1<<1,
	PSPF_OTHER = 1<<2,

	PSPF_OVERLAY = PSPF_WEAPONS|PSPF_CUSTOM_INVENTORY,
	PSPF_ALL = PSPF_OVERLAY|PSPF_OTHER
}

class AnimationInfo
{
	private Actor owner;

	Array<AnimationLayer> layers;

	void CleanUpLayers(bool checkPSprite = true)
	{
		bool player = IsPlayer();

		for (uint i = 0; i < layers.Size(); ++i)
		{
			if (!layers[i]
				|| (checkPSprite && player && !layers[i].GetPSprite()))
			{
				layers.Delete(i--);
			}
		}
	}

	Actor GetOwner() const
	{
		return owner;
	}

	bool Matches(Actor mo) const
	{
		return owner == mo;
	}

	bool LayerMatches(uint index, int id) const
	{
		if (index >= layers.Size() || !layers[index])
			return false;

		return layers[index].Matches(id);
	}

	bool IsPlayer() const
	{
		return owner && owner.player;
	}

	uint Size() const
	{
		return layers.Size();
	}

	static AnimationInfo Create(Actor owner)
	{
		if (!owner)
			return null;

		let ai = new("AnimationInfo");
		ai.owner = owner;

		return ai;
	}
}

struct Animation play
{
	Array<AnimationInfo> actors;
	
	AnimationLayer, AnimationInfo CreateLayer(Actor owner, int id, int pspID = 0)
	{
		if (!owner)
			return null, null;

		AnimationLayer layer;
		AnimationInfo ai;
		[layer, ai] = FindLayer(owner, id);
		if (layer)
			return layer, ai;
		
		layer = AnimationLayer.Create(owner, id, pspID);
		if (layer)
		{
			if (!ai)
				ai = AddActor(owner);
			if (ai)
				ai.layers.Push(layer);
		}
		
		return layer, ai;
	}

	AnimationInfo AddActor(Actor owner)
	{
		if (!owner)
			return null;

		let ai = FindActor(owner);
		if (!ai)
		{
			ai = AnimationInfo.Create(owner);
			if (ai)
				actors.Push(ai);
		}

		return ai;
	}

	void CleanUpLayers(Actor owner = null, bool checkLayers = true, bool checkPSprite = true)
	{
		for (uint i = 0; i < actors.Size(); ++i)
		{
			if (!actors[i])
			{
				actors.Delete(i--);
				continue;
			}

			if (!checkLayers || (owner && !actors[i].Matches(owner)))
				continue;

			actors[i].CleanUpLayers(checkPSprite);
		}
	}
	
	void RemoveLayers(int id, Actor owner = null)
	{
		for (uint i = 0; i < actors.Size(); ++i)
		{
			if (!actors[i] || (owner && !actors[i].Matches(owner)))
				continue;

			for (uint j = 0; j < actors[i].Size(); ++j)
			{
				if (actors[i].LayerMatches(j, id))
					actors[i].layers.Delete(j--);
			}
		}
	}

	void ModifyLayers(Actor owner = null, EPSpriteFlags pspFlags = PSPF_NONE)
	{
		for (uint i = 0; i < actors.Size(); ++i)
		{
			if (!actors[i] || (owner && !actors[i].Matches(owner)))
				continue;

			let mo = actors[i].GetOwner();
			AddPSprites(mo, pspFlags);

			for (uint j = 0; j < actors[i].Size(); ++j)
			{
				if (actors[i].layers[j])
					actors[i].layers[j].Modify();

				if (!mo)
					break;

				AddPSprites(mo, pspFlags);
			}
		}

		CleanUpLayers();
	}

	void AddPSprites(Actor owner, EPSpriteFlags pspFlags)
	{
		if (pspFlags == PSPF_NONE || !owner || !owner.player || owner.player.mo != owner)
			return;

		let psp = owner.player.psprites;
		while (psp)
		{
			if (((pspFlags & PSPF_WEAPONS) && psp.caller is "Weapon")
				|| ((pspFlags & PSPF_CUSTOM_INVENTORY) && psp.caller is "CustomInventory")
				|| ((pspFlags & PSPF_OTHER) && !(psp.caller is "StateProvider")))
			{
				CreateLayer(owner, psp.id, psp.id);
			}

			psp = psp.next;
		}
	}

	clearscope AnimationInfo FindActor(Actor owner) const
	{
		if (!owner)
			return null;

		for (uint i = 0; i < actors.Size(); ++i)
		{
			if (actors[i] && actors[i].Matches(owner))
				return actors[i];
		}

		return null;
	}
	
	clearscope AnimationLayer, AnimationInfo FindLayer(Actor owner, int id) const
	{
		let ai = FindActor(owner);
		if (!ai)
			return null, null;

		for (uint i = 0; i < ai.Size(); ++i)
		{
			if (ai.LayerMatches(i, id))
				return ai.layers[i], ai;
		}
		
		return null, ai;
	}

	clearscope void FindLayers(int id, out Array<AnimationLayer> layers) const
	{
		layers.Clear();

		for (uint i = 0; i < actors.Size(); ++i)
		{
			if (!actors[i])
				continue;
			
			for (uint j = 0; j < actors[i].Size(); ++j)
			{
				if (actors[i].LayerMatches(j, id))
					layers.Push(actors[i].layers[j]);
			}
		}
	}
	
	clearscope uint ActorCount() const
	{
		return actors.Size();
	}

	clearscope uint LayerCount() const
	{
		uint total;
		for (uint i = 0; i < actors.Size(); ++i)
		{
			if (actors[i])
				total += actors[i].Size();
		}

		return total;
	}
	
	clearscope static int GetSequenceLength(State start, State end = null)
	{
		if (!start || start == end)
			return 0;
			
		int total;
		State thisState = start;
		State prevState;
		do
		{
			if (thisState.tics > 0)
				total += thisState.tics;
								
			prevState = thisState;
			thisState = thisState.NextState;
		} while (thisState && thisState != end && prevState.DistanceTo(thisState) == 1);
		
		return total;
	}
}