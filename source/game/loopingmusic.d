module game.loopingmusic;

import d2d;

__gshared LoopingMusic bgMusic;

struct LoopingMusic
{
	Music intro, looping;
	bool queueLooping;

	extern (C) private static void onMusicFinished() nothrow
	{
		bgMusic.queueLooping = true;
	}

	void start()
	{
		Mix_HookMusicFinished(&LoopingMusic.onMusicFinished);
		intro.play(1);
	}

	void update()
	{
		if (queueLooping)
		{
			looping.play(-1);
			Mix_HookMusicFinished(null);
			queueLooping = false;
		}
	}
}
