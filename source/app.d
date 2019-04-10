import d2d;

class Game1 : Game
{
private:
	bool paused;

protected:
	override void onEvent(Event event)
	{
		super.onEvent(event);

		if (event.type == Event.Type.KeyPressed)
		{
			switch (event.key)
			{
			case SDLK_p:
				paused = !paused;
				break;
			default:
				break;
			}
		}
	}

public:

	override void start()
	{
		windowWidth = 800;
		windowHeight = 608;
		windowTitle = "LGJ2019";
		maxFPS = 120;
	}

	override void load()
	{
	}

	override void update(float delta)
	{
		if (paused)
			return;
	}

	override void draw()
	{
		window.clear(0, 0, 0);
	}
}

void main()
{
	new Game1().run();
}
