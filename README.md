# CAFÉ SHIFT

This is my idea in play for that cafe trial in [PIXL](https://pixl.hackclub.com/trials)
My idea is that make a game where you are the owner of the cafe and you gotta serve the customers, it is fun to play
My project: [PIXL project 1646](https://pixl.hackclub.com/projects/1646). 
My idea in play: [game](https://cafe-shift-rush-hour.vercel.app/)

(<img width="1917" height="908" alt="image" src="https://github.com/user-attachments/assets/dd704294-c1fc-4646-a772-9e9ec0539291" />
)

## Play

I published it on vercel, and am doing the version control using github. 
**[Play](https://cafe-shift-rush-hour.vercel.app/)** · **[Version](https://github.com/Hustlenix/cafe-shift-rush-hour/releases/latest)**

## Verified status
OFC this works, dont trust me?
See: [verification evidence and remaining device-QA limits](docs/VERIFICATION.md).

## Art and licenses

I personally bought the **Modern Interiors** pack from [LimeZu](https://limezu.itch.io/moderninteriors) which supplies the café props and six animated regulars, using stardance's itch.io grant. So, this basically costs 5$🤣. You you wanna use it, command this in your terminal: 

```sh
python -m pip install pillow
python tools/import_assets.py --pack "/path/to/moderninteriors-win"
```

## Architecture
My plan was to recreate PIXL's structure and stuff but it was in and vain💔, i tried my best to recreate it, but it still shows has some random error, idk what to do.
so just dont look at the design, 
enjoy the game,
and **PAY ATTENTION FOR THE WHOLE GAME, TRY NOT TO MISS ANYTHING!**
I am gonna ship this, man✌🏻

## Build and release
**Dependency**
Godot 4.7.1 and the Compatibility renderer. See [Godot Web export documentation](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html).
2. Neon database
3. Vercel
4. Github(optional BTW). guthub is for version control thats it 

**Command**
```sh
godot --headless --path . --export-release Web builds/web/index.html
vercel link
vercel env pull .env.local
npm run db:migrate
vercel deploy --prod
python tools/package_release.py --out builds/release
```

Provision your own Neon database and set `DATABASE_URL` (pooled) and `DATABASE_URL_UNPOOLED` (migration) in Vercel before deploying the API. Do not commit `.env.local`. For local API development, run `npm run dev:backend`; the supported endpoint is `http://127.0.0.1:8790`. Native clients require HTTPS outside that loopback exception.

# Licence
MIT
