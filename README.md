# Porter

A music playing Discord bot

## Commands

### ```!play <query>```

Adds a song to the queue, if the queue is empty it also plays the song.


### ```!play```

Plays the current song in the queue.

### ```!stop```

Stops the current song. This command does **not** remove the song from the queue.

### ```!skip```

Skips the current song (stops the current song, removes it from the queue, plays the next one from the queue).

### ```!queue```

Shows current songs in the queue.

### ```!leave```

Removes the bot from the audio channel.

## Installation

### Prerequisites

* Discord bot token (check out https://discord.com/developers/applications)
* FFmpeg installed
* youtube-dl installed

### Launching 

1. Provide your Discord bot token as a 
```DISCORD_TOKEN``` environment variable
1. Provide a correct path to ```ffmpeg_path``` and ```youtube_dl_path``` variables in the ```config/config.exs``` directory
1. Run ```mix run --no-halt```