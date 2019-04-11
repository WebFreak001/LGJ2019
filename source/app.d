import d2d;
import std.stdio;

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
			case SDLK_j:
				world.speed -= 0.25f;
				writeln("slower (", world.speed, ")");
				break;
			case SDLK_k:
				world.speed += 0.25;
				writeln("faster (", world.speed, ")");
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
			case SDLK_DOWN:
				world.player.velocity.y = 1;
				break;
			case SDLK_UP:
				world.player.velocity.y = -1;
				break;
			case SDLK_LEFT:
				world.player.velocity.x = -1;
				break;
			case SDLK_RIGHT:
				world.player.velocity.x = 1;
				break;
			default:
				break;
			}
		} 
		else if (event.type == Event.Type.KeyReleased)
		{
			switch (event.key)
			{
			case SDLK_DOWN:
				world.player.velocity.y = 0;
				break;
			case SDLK_UP:
				world.player.velocity.y = 0;
				break;
			case SDLK_LEFT:
				world.player.velocity.x = 0;
				break;
			case SDLK_RIGHT:
				world.player.velocity.x = 0;
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
		world.player = new Player();
		world.player.position = vec2(20, 70);
		world.player.speed = 2;
		world.player.velocity = vec2(0,0);
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

		world.player.updatePosition();
		world.update(delta);
	}

	override void draw()
	{
		window.clear(0, 0, 0);
		matrixStack.top = mat4.scaling(2, 2, 2);
		// screen size is 400x304 now

		spriteBatch.begin(R.spritesheet.textures[0]);

		spriteBatch.drawSprite(R.sprites.white4x, vec2(0, 0), vec2(200, 304) / 4.0f, vec4(1, 0, 0, 1));
		spriteBatch.drawSprite(R.sprites.white4x, vec2(200, 0), vec2(200, 304) / 4.0f, vec4(0, 0, 1, 1));

		spriteBatch.drawSprite(R.sprites.player, vec2(16, 16));

		foreach (entity; world.entities)
		{
			if (entity.dead)
				continue;

			spriteBatch.drawSprite(R.sprites.player, entity.position);
		}
		spriteBatch.drawSprite(R.sprites.player, world.player.position);
		writeln(world.player.velocity);

		spriteBatch.end();
		spriteBatch.draw(window);
	}
}

void main()
{
	new Game1().run();
}
