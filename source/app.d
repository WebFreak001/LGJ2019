import d2d;

import resources;

import game.components;
import game.systems;
import game.world;

class Game1 : Game
{
private:
	bool paused;
	GameWorld world;

	DrawSystem drawSystem;

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

				auto entity = world.putEntity(PositionComponent(vec2(100, 100)),
						DisplayComponent(R.sprites.white4x, vec4(1, 1, 1, 0.5f)));

				world.put(History(world.now, world.now + 2, () {
						writeln("unstart");
						world.editEntity!((ref entity) { entity.entity.dead = true; })(entity);
					}, () {
						writeln("restart");
						world.editEntity!((ref entity) { entity.entity.dead = false; })(entity);
					}, () {
						writeln("finish");
						world.editEntity!((ref entity) { entity.entity.dead = true; })(entity);
					}, () {
						writeln("unfinish");
						world.editEntity!((ref entity) { entity.entity.dead = false; })(entity);
					}, (p, d) {
						world.editEntity!((ref entity) {
							entity.write(PositionComponent(vec2(20 + p * 200, 50)));
						})(entity);
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
		drawSystem.load();
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
		// screen size is 400x304 now

		drawSystem.draw(world, window);
	}
}

void main()
{
	new Game1().run();
}
