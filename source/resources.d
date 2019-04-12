module resources;

import d2d;

import std.exception;

struct Resources
{
	alias usedSprites = AliasSeq!("player", "white", "white2x", "white4x", "bullet", "lazer", "torpedo");

	Spritesheet spritesheet;
	// magically wraps all the used sprites as easy to access variables
	typeof(spritesheet.buildLookup!usedSprites(0)) sprites;

	void load()
	{
		spritesheet.load("res/spritesheet.bin");
		enforce(spritesheet.textures.length == 1, "Multi-page spritesheets not supported");
		sprites = spritesheet.buildLookup!usedSprites(0);
	}
}

/// All globally accessible resources
__gshared Resources R;
