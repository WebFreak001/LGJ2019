import d2d;

import resources;

import game.components;
import game.entities.bullet;
import game.level;
import game.loopingmusic;
import game.systems;
import game.world;

import std.stdio : writeln, File;

class Game1 : Game
{
private:
	bool paused;

	CollisionSystem collisions;
	DrawSystem drawSystem;

	Level level;

	RectangleShape gameOverScreen;

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

		bgMusic.start();

		CollisionComponent playerCollision;
		playerCollision.type = CollisionComponent.Mask.player;
		playerCollision.circles[0].radius = 4;
		playerCollision.circles[0].mask = CollisionComponent.Mask.playerShot;
		controls.player = world.putEntity(PositionComponent(vec2(CanvasWidth / 2,
				CanvasHeight / 2)), ComplexDisplayComponent(R.sprites.player),
				HealthComponent(3, 3), playerCollision);

		level = Level.parse(File("res/level.txt").byLine);

		gameOverScreen = RectangleShape.create(new Texture("res/screen/gameover.png",
				TextureFilterMode.Nearest, TextureFilterMode.Nearest), vec2(0), vec2(400, 304));
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

		bool dead = false;
		controls.player.editEntity!((ref player) {
			auto health = player.read!HealthComponent;
			dead = health.hp == 0;
		});
		if (dead)
			window.draw(gameOverScreen);
		else
			drawSystem.draw(window, controls);
	}
}

void main()
{
	new Game1().run();
}
