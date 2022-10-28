class AnimationLayer : Object play
{
	int id;
	Actor owner;
	int pspID;
	
	double modifier;
	State start;
	int tics;
	bool bSetModifier;
	
	int timer;
	double roundUp;
	
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
		
		State thisState = s;
		if (!thisState)
		{
			if (pspID)
			{
				if (owner.player)
				{
					let psp = owner.player.FindPSprite(pspID);
					if (psp)
						thisState = psp.CurState;
				}
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
		if (modifier ~== 1)
			return true;
			
		State thisState;
		PSprite psp;
		if (pspID)
		{
			if (owner.player)
				psp = owner.player.FindPSprite(pspID);
		}
		
		if (pspID)
		{
			if (psp)
				thisState = psp.CurState;
		}
		else
			thisState = owner.CurState;
		
		// Don't modify if the owner is frozen or time timer is still ticking
		if (!thisState || thisState.tics == -1 || owner.IsFrozen())
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
}

struct Animation play
{
	Array<AnimationLayer> layers;
	
	AnimationLayer CreateLayer(Actor owner, int id, int pspID = 0)
	{
		// Layer already exists
		let layer = FindLayer(id);
		if (layer)
			return layer;
			
		layer = new("AnimationLayer");
		if (!layer)
			return null;
		
		layer.owner = owner;
		layer.id = id;
		layer.pspID = pspID;
		
		layer.Reset();
		layers.Push(layer);
		
		return layer;
	}
	
	void RemoveLayer(int id)
	{
		let layer = FindLayer(id);
		if (layer)
		{
			layers.Delete(layers.Find(layer));
			layer.Destroy();
		}
	}
	
	AnimationLayer FindLayer(int id)
	{
		for (uint i = 0; i < Count(); ++i)
		{
			if (layers[i] && layers[i].id == id)
				return layers[i];
		}
		
		return null;
	}
	
	uint Count()
	{
		return layers.Size();
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