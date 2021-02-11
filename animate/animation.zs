class AnimationLayer : Object play
{
	int id;
	Actor owner;
	PSprite psp;
	
	double modifier;
	State start;
	int tics;
	
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
	
	void SetModifier(double mod, State start = null)
	{
		Reset();
		
		State thisState = start;
		if (!thisState)
		{
			if (psp)
				thisState = psp.CurState;
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
	}
	
	void ChangeModifier(double mod)
	{
		if (mod < 0)
			mod = 0;
			
		modifier = mod;
		
		timer = 0;
		roundUp = 0;
	}
	
	void Modify()
	{
		if (modifier == 1)
			return;
			
		State thisState;
		if (psp)
			thisState = psp.CurState;
		else
			thisState = owner.CurState;
		
		// Don't modify if we're in a freeze state
		if (!thisState || thisState.tics == -1)
			return;
			
		if (--timer <= 0)
		{
			double interval;
			if (modifier > 1)
				interval = modifier;
			else
			{
				int ticsLeft = round(tics * (1 - modifier));
				if (ticsLeft > 0)
					interval = (tics-ticsLeft)*1. / ticsLeft;
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
			
			int cap = Animation.GetSequenceLength(thisState) - 1; // Don't allow 0-length animations
			int mod = 1;
			if (!modifier)
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
				if (psp)
					psp.tics += mod;
				else
					owner.tics += mod;
			}
			else
			{
				if (psp)
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
								State next = psp.CurState.NextState;
								
								psp.SetState(next);
								if (!ContinueAnimating(next, prev, true))
									return;
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
								State next = owner.CurState.NextState;
								
								owner.SetState(next);
								if (!ContinueAnimating(next, prev))
									return;
							}
						} while (tempMod > 0);
					}
				}
			}
		}
	}
	
	private bool ContinueAnimating(State current, State prev, bool isPSprite = false)
	{
		if (!owner || (isPSprite && !psp)
			|| !current || current.tics == -1 || current == start
			|| (prev && prev.DistanceTo(current) != 1))
		{
			return false;
		}
		
		return true;
	}
}

struct Animation play
{
	Array<AnimationLayer> layers;
	
	AnimationLayer CreateLayer(Actor owner, int id, PSprite psp = null)
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
		layer.psp = psp;
		
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
	
	static int GetSequenceLength(State start)
	{
		if (!start)
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
		} while (thisState && prevState.DistanceTo(thisState) == 1);
		
		return total;
	}
}