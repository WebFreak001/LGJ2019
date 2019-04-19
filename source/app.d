import d2d;

import resources;

import game.components;
import game.entities.bullet;
import game.level;
import game.loopingmusic;
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
		Music.load();

		R.load();
		drawSystem.load();

		bgMusic = LoopingMusic(new Music("res/music/spacinginspace.mp3"),
				new Music("res/music/spacinginspace-main.mp3"));

		// bgMusic.start();

		CollisionComponent playerCollision;
		playerCollision.type = CollisionComponent.Mask.player;
		playerCollision.circles[0].radius = 4;
		playerCollision.circles[0].mask = CollisionComponent.Mask.playerShot;
		controls.player = world.putEntity(PositionComponent(vec2(CanvasWidth / 2,
				CanvasHeight / 2)), ComplexDisplayComponent(R.sprites.player),
				HealthComponent(3, 3), playerCollision);

		Section section;
		section.events ~= Section.Event(3, &spawnEnemy);
		section.events ~= Section.Event(5, (ref self) { writeln("endless wait"); });
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
		enemy.onDeath = () {
			self.finished = true;
			world.endNow(start, enemy.historyID);
		};
		makeChildEffects(self, enemy, world.now + 1);
	}

	void makeChildEffects(ref Section.Event event, LinearBulletEntity entity, double time)
	{
		world.put(History.makeTrigger(time, {
				makeChildEffects(event, entity, time);
			}, {
				if (event.finished)
					return;
				shootChild(entity);
				makeChildEffects(event, entity, world.now + 1);
			}, entity.historyID, -1));
	}

	void shootChild(LinearBulletEntity entity)
	{
		entity.edit!((ref entity) {
			vec2 start = entity.read!PositionComponent.position + vec2(0, 16);

			vec2 direction = vec2(-1, 0);
			editEntity!((ref entity) {
				direction = (entity.read!PositionComponent.position - start).normalized;
			})(controls.player);

			//dfmt off
			new LinearBulletEntity(R.sprites.lazer, direction * 300, vec2(1), vec4(1, 1, 1, 1))
					.maxHealth(1)
					.addCircle(CollisionComponent.Mask.enemyShot, vec2(-12, 0), 4)
					.addCircle(CollisionComponent.Mask.enemyShot, vec2(-6, 0), 4)
					.addCircle(CollisionComponent.Mask.enemyShot, vec2(6, 0), 4)
					.addCircle(CollisionComponent.Mask.enemyShot, vec2(12, 0), 4)
					.create(start, 0, 2);
			//dfmt on
		});
	}

	override void update(float delta)
	{
		bgMusic.update();

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
