import d2d;

import resources;

import game.world;

class Game1 : Game
{
private:
	bool paused;
	SpriteBatch spriteBatch;
	World world;

protected:
	override void onEvent(Event event)
	{
		import std.stdio : writeln;

		super.onEvent(event);

		if (event.type == Event.Type.KeyPressed)
		{
			switch (event.key)
			{
			case SDLK_p:
				paused = !paused;
				break;
			case SDLK_LEFTBRACKET:
				writeln("slower");
				world.speed -= 0.3f;
				break;
			case SDLK_RIGHTBRACKET:
				writeln("faster");
				world.speed += 0.3f;
				break;
			case SDLK_SPACE:
				writeln("spawning projectile");

				Entity e = new Entity();
				e.dead = true;

				world.entities ~= e;
				world.put(History(world.now + 1, world.now + 3, () {
						writeln("unstart");
						e.dead = true;
					}, () { writeln("restart"); e.dead = false; }, () {
						writeln("finish");
						e.dead = true;
					}, () { writeln("unfinish"); e.dead = false; }, (p, d) {
						e.position = vec2(20 + p * 200, 50);
					}));
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

		world.update(delta);
	}

	override void draw()
	{
		window.clear(0, 0, 0);
		matrixStack.top = mat4.scaling(2, 2, 2);

		spriteBatch.begin(R.spritesheet.textures[0]);

		spriteBatch.drawSprite(R.sprites.player, vec2(16, 16));

		foreach (entity; world.entities)
		{
			if (entity.dead)
				continue;

			spriteBatch.drawSprite(R.sprites.player, entity.position);
		}

		spriteBatch.end();
		window.draw(spriteBatch);
	}
}

void main()
{
	new Game1().run();
}
