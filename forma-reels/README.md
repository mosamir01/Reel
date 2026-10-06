# Forma talking-head ad reels

> For the animated presenter style (like the reference reel), see [`motion/`](motion/README.md).
> This folder is the version for filming yourself on camera.

Five UGC-style scripts. Each is one person talking straight to camera about Forma, with
a hook banner up top, bold captions and a Forma end card. Each one runs about 25–30 seconds.

## Make one
1. Film yourself on your phone (vertical, eye level, window light) reading a script below.
   Talk the way you'd tell a friend about it. Trim dead air at the start and end.
2. Run `python3 make_reel.py ads/01_failed_every_habit.json --clip my_take.mp4`
   (add `--music track.mp3` for a quiet music bed). The output goes to `renders/`.
3. Running it without `--clip` makes a placeholder preview so you can check pacing first.

Captions are spread over the clip by word count. If they drift, give every line a timing,
e.g. `{"text": "Then I found Forma.", "t": [6.2, 7.4]}`.

**B-roll tip:** cut to a 1–2 second screen recording of Forma whenever the script says
"tap", "streak", "widget" or "stats". Showing the app on screen gets the point across faster.

## Scripts

### I failed every habit app  (`ads/01_failed_every_habit.json`)
**Hook on screen:** I quit every habit app within a week  
> Okay, real talk.
> I have downloaded probably ten habit trackers.
> And I quit every single one within a week.
> Too many buttons. Too many settings. Too much guilt.
> Then I found Forma.
> You open it, you tap your habit, done.
> Literally two seconds.
> And seeing that streak grow every day?
> Weirdly addictive.
> I'm on day forty-three now.
> If you keep giving up on your habits, try Forma.

**End card:** Download Forma — free on the App Store

### POV: you finally kept a streak  (`ads/02_pov_streak.json`)
**Hook on screen:** POV: you actually kept a habit for once  
> This is what fifty days of not skipping looks like.
> Drink water. Read ten pages. Walk.
> Nothing crazy.
> The difference is I track it in Forma now.
> Every check-in fills in my little grid,
> and I do not want to break the chain.
> That's the whole trick.
> It's not motivation. It's just not wanting to lose the streak.
> Link's in my bio. Start yours today.

**End card:** Start your streak — with Forma

### 3 reasons I switched  (`ads/03_three_reasons.json`)
**Hook on screen:** 3 reasons I switched to Forma  
> Three reasons I switched to Forma.
> One. It's actually simple.
> No setup. Add a habit in like five seconds.
> Two. The widget.
> My habits are right on my home screen, so I can't pretend I forgot.
> Three. The stats.
> I can see which days I slack off, and fix it.
> Honestly, it's the first habit app I've kept for more than a month.
> Go try it.

**End card:** Forma — habits that stick

### Stop scrolling, start this  (`ads/04_stop_scrolling.json`)
**Hook on screen:** If you keep saying "I'll start Monday"  
> If you keep saying you'll start on Monday,
> this is for you.
> You don't need a new planner, or a whole new routine.
> Pick one habit. Just one.
> Put it in Forma.
> Check it off every day.
> That's it.
> In a month you'll look back at your streak and be shocked.
> Don't wait for Monday. Start today.

**End card:** Download Forma — start today

### My morning routine, tracked  (`ads/05_morning_routine.json`)
**Hook on screen:** How I finally stuck to a morning routine  
> I tried to build a morning routine for two years.
> Never stuck.
> Here's what changed.
> I put every step into Forma.
> Wake up. Water. Stretch. No phone for thirty minutes.
> Forma reminds me, I tick them off,
> and by eight AM my whole day is already a win.
> Small habits, every day. That's how you change.
> Try Forma. It's free.

**End card:** Build your routine — with Forma
