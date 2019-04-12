import d2d;

import resources;

import game.entities.bullet;
import game.components;
import game.level;
import game.systems;
import game.world;

import std.stdio : writeln;

class Game1 : Game
{
private:
	bool paused;
	GameWorld world;

	Controls controls;
	DrawSystem drawSystem;

	Level level;

protected:
	override void onEvent(Event event)
	{
		super.onEvent(event);

		controls.handleEvent(world, event);
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

		controls.player = world.putEntity(PositionComponent(vec2(200, 152)),
				ComplexDisplayComponent(R.sprites.player));

		Section section;
		section.events ~= Section.Event(3, &spawnEnemy);
		section.events ~= Section.Event(5, (ref world, ref self) {
			writeln("endless wait");
		});
		level.sections ~= section;
	}

	void spawnEnemy(ref GameWorld world, ref Section.Event self)
	{
		writeln("spawning enemy");

		auto enemy = new LinearBulletEntity(R.sprites.ufo, vec2(-100, 0), vec2(1), vec4(1), 0).addCircle(
				CollisionComponent.Mask.enemyGeneric, vec2(0, 0), 16);
		enemy.create(world, vec2(420, 152), 0, 4.5);
		enemy.onDeath = () { self.finished = true; };
	}

	override void update(float delta)
	{
		if (paused)
			return;

		world.update(delta);
		level.update(world);

		double deltaWorld = delta * world.speed;

		controls.update(world, delta, deltaWorld);
	}

	override void draw()
	{
		window.clear(drawSystem.bg.fR, drawSystem.bg.fG, drawSystem.bg.fB);
		matrixStack.top = mat4.scaling(2, 2, 2);
		// screen size is 400x304 now

		drawSystem.draw(world, window, controls);
	}
}

void main()
{
	new Game1().run();
}
