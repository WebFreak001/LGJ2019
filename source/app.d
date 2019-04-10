import d2d;

import resources;

class Game1 : Game
{
private:
	bool paused;
	SpriteBatch spriteBatch;

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
		R.load();

		spriteBatch = new SpriteBatch();
	}

	override void update(float delta)
	{
		if (paused)
			return;
	}

	override void draw()
	{
		window.clear(0, 0, 0);

		spriteBatch.begin(R.spritesheet.textures[0]);

		spriteBatch.drawSprite(R.sprites.player, vec2(16, 16));

		spriteBatch.end();
		window.draw(spriteBatch);
	}
}

void main()
{
	new Game1().run();
}
