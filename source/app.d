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

	Controls controls;
	CollisionSystem collisions;
	DrawSystem drawSystem;

	Level level;

protected:
	override void onEvent(Event event)
	{
		super.onEvent(event);

		controls.handleEvent(event);
	}

public:

	override void start()
	{
		windowWidth = WindowWidth;
		windowHeight = WindowHeight;
		windowTitle = "LGJ2019";
		maxFPS = 120;
	}

	override void load()
	{
		R.load();
		drawSystem.load();

		CollisionComponent playerCollision;
		playerCollision.type = CollisionComponent.Mask.player;
		playerCollision.circles[0].radius = 16;
		playerCollision.circles[0].mask = CollisionComponent.Mask.playerShot;
		controls.player = world.putEntity(PositionComponent(vec2(CanvasWidth / 2,
				CanvasHeight / 2)), ComplexDisplayComponent(R.sprites.player),
				HealthComponent(3, 3), playerCollision);

		Section section;
		section.events ~= Section.Event(3, &spawnEnemy);
		section.events ~= Section.Event(5, (ref self) {
			writeln("endless wait");
		});
		level.sections ~= section;
	}

	void spawnEnemy(ref Section.Event self)
	{
		writeln("spawning enemy");

		auto enemy = new LinearBulletEntity(R.sprites.ufo, vec2(-100, 0), vec2(1), vec4(1), 0).maxHealth(2)
			.type(CollisionComponent.Mask.enemyGeneric).addCircle(
					CollisionComponent.Mask.enemyShot, vec2(0, 0), 16);
		auto start = world.now;
		enemy.create(vec2(CanvasWidth + 16, CanvasHeight / 2), 0, 4.5);
		enemy.onDeath = () { self.finished = true; world.endNow(start, enemy.historyID); };
	}

	override void update(float delta)
	{
		if (paused)
			return;

		world.update(delta);
		level.update();

		double deltaWorld = delta * world.speed;

		collisions.update(deltaWorld);
		controls.update(delta, deltaWorld);
	}

	override void draw()
	{
		window.clear(drawSystem.bg.fR, drawSystem.bg.fG, drawSystem.bg.fB);
		matrixStack.top = mat4.scaling(CanvasScale, CanvasScale, 1);

		drawSystem.draw(window, controls);
	}
}

void main()
{
	new Game1().run();
}
