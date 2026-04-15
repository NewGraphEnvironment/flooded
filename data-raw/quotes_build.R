# Build script for flooded startup quotes.
#
# Source of truth. Run to regenerate:
#   data-raw/quotes_audit.csv    (full provenance — tracked, not shipped)
#   inst/extdata/quotes.csv      (shipped, read by R/zzz.R)
#
# Rscript data-raw/quotes_build.R
#
# Every row must carry a primary-source URL confirmed on verification_date.

library(tibble)

quotes <- tribble(
  ~quote, ~author, ~source, ~source_type, ~source_outlet, ~verification_date,

  # --- HIP-HOP ---

  # Kanye West (5)
  "It's like everyone's born an artist, and born confident, and everything's taken away from you.",
  "Kanye West", "https://www.thefader.com/2013/10/23/kanye-west-unedited-the-complete-fader-interview-2008",
  "interview", "The FADER (2008 interview, pub. 2013)", "2026-04-14",

  "My whole life I've never really been that talented at anything except for working at something to the point where it was good.",
  "Kanye West", "https://www.thefader.com/2013/10/23/kanye-west-unedited-the-complete-fader-interview-2008",
  "interview", "The FADER (2008)", "2026-04-14",

  "Time is the only luxury. It's the only thing you can't get back.",
  "Kanye West", "https://www.vice.com/en_us/article/d745yj/9-quotes-on-creativity-from-kanye-wests-oxford-speech",
  "speech", "Oxford Guild Society, 2015 (via VICE)", "2026-04-14",

  "We're all works in progress. We're paintings. The oil don't dry till we die.",
  "Kanye West", "https://www.complex.com/style/2013/11/kanye-west-quotes-creativity",
  "interview", "Kanye West on Twitter / Complex compilation", "2026-04-14",

  "I don't care about my name as much as I care about my ideas.",
  "Kanye West", "https://www.wmagazine.com/story/kanye-west-on-kim-kardashian-and-his-new-album-yeezus",
  "interview", "W Magazine, June 2013", "2026-04-14",

  # Royce da 5'9" (5)
  "All of my problems that I had, all roads led back to liquor somehow. I made my job so much harder.",
  "Royce da 5'9\"", "https://andscape.com/features/royce-da-59-on-sobriety-boxing-and-why-he-stopped-watching-nba-games/",
  "interview", "Andscape (ESPN)", "2026-04-14",

  "I've arrived at a place where whatever I'm writing down, if it comes from the heart, it really shouldn't take me a lot of time to think about it.",
  "Royce da 5'9\"", "https://andscape.com/features/royce-da-59-on-sobriety-boxing-and-why-he-stopped-watching-nba-games/",
  "interview", "Andscape (ESPN)", "2026-04-14",

  "It's easier to open up and let it flow like I'm in therapy than it is to try to come up with punchlines.",
  "Royce da 5'9\"", "https://andscape.com/features/royce-da-59-on-sobriety-boxing-and-why-he-stopped-watching-nba-games/",
  "interview", "Andscape (ESPN)", "2026-04-14",

  "Every artist should have at least one album where you feel like you know the individual you're listening to after listening to the music.",
  "Royce da 5'9\"", "https://andscape.com/features/royce-da-59-on-sobriety-boxing-and-why-he-stopped-watching-nba-games/",
  "interview", "Andscape (ESPN)", "2026-04-14",

  "Since I've been sober I've been so comfortable in my skin now.",
  "Royce da 5'9\"", "https://thesource.com/2018/03/13/royce-da-59-talks-being-sober-kanye-west-beef-and-joe-budden-on-rap-radar/",
  "interview", "Rap Radar via The Source, 2018", "2026-04-14",

  # Black Thought (5)
  "Art saved me from becoming a statistic, as so many of my friends and family members and neighbors and just so many of my contemporaries had and have become.",
  "Black Thought", "https://www.pbs.org/newshour/show/tariq-black-thought-trotter-on-his-impact-on-hip-hop-and-new-memoir-the-upcycled-self",
  "interview", "PBS NewsHour (2023)", "2026-04-14",

  "It's about understanding the difference between that which needs to be abandoned and that which needs to be put to a different use.",
  "Black Thought", "https://www.pbs.org/newshour/show/tariq-black-thought-trotter-on-his-impact-on-hip-hop-and-new-memoir-the-upcycled-self",
  "interview", "PBS NewsHour (2023)", "2026-04-14",

  "It's not always comfortable to lean into your talents and to lean into your graces, but it's sort of our responsibility as artists.",
  "Black Thought", "https://www.pbs.org/newshour/show/tariq-black-thought-trotter-on-his-impact-on-hip-hop-and-new-memoir-the-upcycled-self",
  "interview", "PBS NewsHour (2023)", "2026-04-14",

  "Art has been my saving grace, my salvation, absolutely.",
  "Black Thought", "https://www.cbsnews.com/news/the-roots-tariq-trotter-black-thought-art-saving-grace-my-salvation/",
  "interview", "CBS Sunday Morning (2023)", "2026-04-14",

  "I haven't failed myself yet. Am I always at my best? No, but my worst is the next man's treasure.",
  "Black Thought", "https://www.cbsnews.com/news/the-roots-tariq-trotter-black-thought-art-saving-grace-my-salvation/",
  "interview", "CBS Sunday Morning (2023)", "2026-04-14",

  # Ab-Soul (4)
  "You can't force art; you can't force your creativity. It has to happen naturally on your time, on your accord.",
  "Ab-Soul", "https://www.theringer.com/2022/12/20/music/ab-soul-new-album-herbert-interview",
  "interview", "The Ringer (HERBERT), December 2022", "2026-04-14",

  "I've been through a lot, man. I took a lot of losses. I had a lot of wins. And it all happened for a reason, I feel, to prepare me for what's to come.",
  "Ab-Soul", "https://www.theringer.com/2022/12/20/music/ab-soul-new-album-herbert-interview",
  "interview", "The Ringer, December 2022", "2026-04-14",

  "I tried to remove a lot of my arrogance with this album. My ego. And just put it in God's hands and hope for the best.",
  "Ab-Soul", "https://www.theringer.com/2022/12/20/music/ab-soul-new-album-herbert-interview",
  "interview", "The Ringer, December 2022", "2026-04-14",

  "It is a miracle I am still here. I'm grateful.",
  "Ab-Soul", "https://www.theringer.com/2022/12/20/music/ab-soul-new-album-herbert-interview",
  "interview", "The Ringer, December 2022", "2026-04-14",

  # ASAP Rocky (5)
  "Obviously I wasn't born privileged or with success in easy reach. So I had to develop into the man that I've become.",
  "ASAP Rocky", "https://www.thegentlemansjournal.com/article/asap-rocky-interview/",
  "interview", "The Gentleman's Journal", "2026-04-14",

  "It's been a long night, long day, long few years, man. But that's the way I like it.",
  "ASAP Rocky", "https://www.thegentlemansjournal.com/article/asap-rocky-interview/",
  "interview", "The Gentleman's Journal", "2026-04-14",

  "I really thought I was special enough to end. I was kind of upset when I turned 28.",
  "ASAP Rocky", "https://www.thegentlemansjournal.com/article/asap-rocky-interview/",
  "interview", "The Gentleman's Journal (on the 27 Club)", "2026-04-14",

  "Home is anywhere that I have my lady and my children — that is home.",
  "ASAP Rocky", "https://www.dazeddigital.com/beauty/article/60980/1/asap-rocky-interview-gucci-new-album-2023",
  "interview", "Dazed, 2023", "2026-04-14",

  "Being able to flip things and make it your own and make an origin out of it and start something new, that's the trick and that's the magic within it all — creating an expression and expressing yourself.",
  "ASAP Rocky", "https://www.dazeddigital.com/beauty/article/60980/1/asap-rocky-interview-gucci-new-album-2023",
  "interview", "Dazed, 2023", "2026-04-14",

  # Danny Brown (5)
  "Man, when it's the time, it's the time. It's almost like life is a school, and when you die, it's graduation.",
  "Danny Brown", "https://www.rollingstone.com/music/music-features/danny-brown-drugs-rehab-new-album-1234800909/",
  "interview", "Rolling Stone (Quaranta)", "2026-04-14",

  "I didn't know how long I was going to be living.",
  "Danny Brown", "https://www.rollingstone.com/music/music-features/danny-brown-drugs-rehab-new-album-1234800909/",
  "interview", "Rolling Stone", "2026-04-14",

  "I didn't love myself at the time, so it was impossible for me to love anything else.",
  "Danny Brown", "https://www.nme.com/features/music-interviews/danny-brown-stardust-hyperpop-interview-3905040",
  "interview", "NME", "2026-04-14",

  "That's when I stopped trying to be like everybody else and realised I could be myself.",
  "Danny Brown", "https://www.nme.com/features/music-interviews/danny-brown-stardust-hyperpop-interview-3905040",
  "interview", "NME", "2026-04-14",

  "I had to go into a different mode and write from a different perspective.",
  "Danny Brown", "https://www.nme.com/features/music-interviews/danny-brown-stardust-hyperpop-interview-3905040",
  "interview", "NME", "2026-04-14",

  # The Weeknd (5)
  "The lines were blurry at the beginning. And as my career developed — as I developed as a man — it's become very clear that Abel is someone I go home to every night. And The Weeknd is someone I go to work as.",
  "The Weeknd", "https://www.gq.com/story/the-weeknd-september-cover-interview",
  "interview", "GQ cover, September 2021 (Mark Anthony Green)", "2026-04-14",

  "Drugs were a crutch. It was me thinking that I needed it. And not doing the work to figure out how not to need it.",
  "The Weeknd", "https://www.gq.com/story/the-weeknd-september-cover-interview",
  "interview", "GQ cover, September 2021", "2026-04-14",

  "This is my first time even opening up to anything, because I had to spend the last decade invested in this project, the Weeknd. It really does consume me.",
  "The Weeknd", "https://www.rollingstone.com/music/music-features/the-weeknd-after-hours-grammys-interview-1061041/",
  "interview", "Rolling Stone (After Hours)", "2026-04-14",

  "I tell my friends all the time it feels like my career is just starting. I feel like it took me 10 years to break out of that shell.",
  "The Weeknd", "https://www.rollingstone.com/music/music-features/the-weeknd-after-hours-grammys-interview-1061041/",
  "interview", "Rolling Stone (After Hours)", "2026-04-14",

  "It might not be my best album. It might not be what people gravitate towards the most in the future. Hopefully it is. But to me, it's definitely my most perfect album.",
  "The Weeknd", "https://www.rollingstone.com/music/music-features/the-weeknd-after-hours-grammys-interview-1061041/",
  "interview", "Rolling Stone (After Hours)", "2026-04-14",

  # Kenny Beats (5)
  "All I do is facilitate. I really am a janitor.",
  "Kenny Beats", "https://www.nme.com/features/music-interviews/kenny-beats-interview-denzel-curry-rico-nasty-idles-the-cave-2623803",
  "interview", "NME", "2026-04-14",

  "I always had this ego where if I ever wanted to come back to doing rap, I could do that. That was not true. I would get stuck, I would be in a room and someone would ask me for something and I didn't have it.",
  "Kenny Beats", "https://www.dazeddigital.com/music/article/46394/1/kenny-beats-how-to-produce-a-legendary-rap-freestyle-interview",
  "interview", "Dazed", "2026-04-14",

  "The biggest thing Rick Rubin taught me is that you don't get any extra credit by doing everything yourself.",
  "Kenny Beats", "https://www.dazeddigital.com/music/article/46394/1/kenny-beats-how-to-produce-a-legendary-rap-freestyle-interview",
  "interview", "Dazed", "2026-04-14",

  "As soon as you think, 'Oh, I'm a really good producer, I'm gonna show these young rap kids how to make a really clean, hot rap beat'... You just missed the fucking point.",
  "Kenny Beats", "https://www.thefader.com/2018/06/04/kenny-beats-loudpvck-777-smack-a-bitch-beat-construction-interview",
  "interview", "The FADER (Beat Construction)", "2026-04-14",

  "I don't have an agenda. My agenda is to take someone and bring out their dreams.",
  "Kenny Beats", "https://www.rollingstone.com/music/music-features/kenny-beats-rap-03-greedo-vince-staples-rico-nasty-770433/",
  "interview", "Rolling Stone", "2026-04-14",

  # Freddie Gibbs (3)
  "I've had the most unique career path of any rapper on my level because I slugged it out so many years independently.",
  "Freddie Gibbs", "https://www.rollingstone.com/music/music-features/freddie-gibbs-interview-new-album-1234601948/",
  "interview", "Rolling Stone (Soul Sold Separately)", "2026-04-14",

  "I probably been having fun rapping the past five years, but before that, I was rapping for a necessity, because I had to.",
  "Freddie Gibbs", "https://www.rollingstone.com/music/music-features/freddie-gibbs-interview-new-album-1234601948/",
  "interview", "Rolling Stone", "2026-04-14",

  "I had to take a lot of risks to get here. And Soul Sold Separately, I just feel like that just culminates all the risks that I took.",
  "Freddie Gibbs", "https://www.rollingstone.com/music/music-features/freddie-gibbs-interview-new-album-1234601948/",
  "interview", "Rolling Stone", "2026-04-14",

  # Madlib (3)
  "It's natural. If you sit there and think about it too much, your shit probably whack.",
  "Madlib", "https://www.redbullmusicacademy.com/lectures/madlib-2016/",
  "lecture", "Red Bull Music Academy, 2016", "2026-04-14",

  "I don't like shit too perfect. I like some human mistake in my shit.",
  "Madlib", "https://www.redbullmusicacademy.com/lectures/madlib-2016/",
  "lecture", "Red Bull Music Academy, 2016", "2026-04-14",

  "I shut off from the world. It's just something you can't try to do. It's just something that happens.",
  "Madlib", "https://www.redbullmusicacademy.com/lectures/madlib-2016/",
  "lecture", "Red Bull Music Academy, 2016", "2026-04-14",

  # Travis Scott (3)
  "I like spaces. I love experiences. I love things that make you come alive.",
  "Travis Scott", "https://www.rollingstone.com/music/music-features/travis-scott-utopia-fatherhood-next-album-1235500436/",
  "interview", "Rolling Stone (Utopia cover, 2025)", "2026-04-14",

  "I want them to know I have pain too. I have concerns, things that I think about, and the things I see on a day-to-day basis I think about them. And every day I want to find change in the things, to make things better, make myself better.",
  "Travis Scott", "https://www.gq.com/story/travis-scott-men-of-the-year-2023-cover-story",
  "interview", "GQ Men of the Year, November 2023", "2026-04-14",

  "I go through things like everyone else. And even recently through something like I never could imagine.",
  "Travis Scott", "https://www.gq.com/story/travis-scott-men-of-the-year-2023-cover-story",
  "interview", "GQ Men of the Year, November 2023", "2026-04-14",

  # Erick the Architect (3)
  "I'm okay with the things that I've lost, because I've gained more than what I lost.",
  "Erick the Architect", "https://www.rollingstone.com/music/music-features/erick-the-architect-ive-never-been-here-before-1234902646/",
  "interview", "Rolling Stone", "2026-04-14",

  "I'm always serving other people with my ideas, and eventually I have to be a little selfish and do that for myself. And I never made time for myself before.",
  "Erick the Architect", "https://www.bkmag.com/2024/04/08/erick-the-architect/",
  "interview", "Brooklyn Magazine", "2026-04-14",

  "I'm being so honest. If my honesty makes you uncomfortable, then I'm not the artist for you.",
  "Erick the Architect", "https://www.bkmag.com/2024/04/08/erick-the-architect/",
  "interview", "Brooklyn Magazine", "2026-04-14",

  # Zombie Juice (3)
  "My goal was not to be heroic, but to be human — the opposite of what goes down on social media and this fast-paced world where everyone wants to be the one and puts on fronts to make it look good.",
  "Zombie Juice", "https://www.bkmag.com/2023/05/16/zombie-juice-wants-you-to-know-its-okay-to-feel/",
  "interview", "Brooklyn Magazine (2023)", "2026-04-14",

  "I want them to enjoy it, hopefully relate to it, replay it over and over and know it's okay to feel. We don't have to be emotionless. Let's process things.",
  "Zombie Juice", "https://www.bkmag.com/2023/05/16/zombie-juice-wants-you-to-know-its-okay-to-feel/",
  "interview", "Brooklyn Magazine (2023)", "2026-04-14",

  "If you care enough, you need to figure out how your person needs to receive love so that they can feel safe and so that they can feel honored.",
  "Zombie Juice", "https://officemagazine.net/zombie-juice-chooses-love",
  "interview", "Office Magazine", "2026-04-14",

  # Meechy Darko (3)
  "Grief is a very complicated thing. There's no handbook on how to, and if there is, it's bullshit.",
  "Meechy Darko", "https://www.thelineofbestfit.com/features/interviews/meechy-darko-rewriting-history",
  "interview", "The Line of Best Fit (Gothic Luxury)", "2026-04-14",

  "The dark cloud is hovering over me but it's not going to stop me from doing what I'm doing.",
  "Meechy Darko", "https://www.thelineofbestfit.com/features/interviews/meechy-darko-rewriting-history",
  "interview", "The Line of Best Fit", "2026-04-14",

  "I see the power in what I say. I gotta make sure to do it the right way when I'm touching certain topics.",
  "Meechy Darko", "https://www.clashmusic.com/features/for-the-first-time-ever-i-see-the-power-in-what-i-say-meechy-darko-on-his-solo-debut/",
  "interview", "Clash Magazine", "2026-04-14",

  # J. Cole (3)
  "I've reached the point in my life where I'm like, 'How long am I gonna be doing this for?' I'm starting to realize like, oh shit — let's say I stopped this year. I would feel like I missed out on certain experiences, working with certain artists, being more collaborative, making more friends out of peers, making certain memories that I feel like if I don't, I'm gonna regret it one day.",
  "J. Cole", "https://www.gq.com/story/j-cole-cover-story-april-2019",
  "interview", "GQ cover, April 2019", "2026-04-14",

  "I'm not supposed to have a Grammy, you know what I mean? At least not right now, and maybe never. And if that happens, then that's just how it was supposed to be.",
  "J. Cole", "https://www.gq.com/story/j-cole-cover-story-april-2019",
  "interview", "GQ cover, April 2019", "2026-04-14",

  "I've been so secluded within myself that people think I don't like anybody, that I won't work with anybody.",
  "J. Cole", "https://www.gq.com/story/j-cole-cover-story-april-2019",
  "interview", "GQ cover, April 2019", "2026-04-14",

  # Bad Bunny (2)
  "There are people who come into your life, and they enjoy the best of you, the nice version from the first few months, and then they leave.",
  "Bad Bunny", "https://www.rollingstone.com/music/music-features/bad-bunny-puerto-rico-new-album-acting-interview-1235227338/",
  "interview", "Rolling Stone cover, Jul/Aug 2023", "2026-04-14",

  "That's what makes me human. I think people are used to artists getting big and mainstream and not expressing themselves about these things.",
  "Bad Bunny", "https://www.rollingstone.com/music/music-features/bad-bunny-puerto-rico-new-album-acting-interview-1235227338/",
  "interview", "Rolling Stone cover, Jul/Aug 2023", "2026-04-14",

  # Don Toliver (2)
  "I'm a Gemini. I believe that I have different sides, and I pick and choose which one I feel is right for the right track and right for the right mood.",
  "Don Toliver", "https://www.complex.com/music/a/frazier-tharpe/don-tolliver-interview-no-idea",
  "interview", "Complex", "2026-04-14",

  "It's just like a big turnaround in my life, from where I was to where I'm at right now. I'm definitely grateful and feeling real grace, for real.",
  "Don Toliver", "https://www.complex.com/music/a/frazier-tharpe/don-tolliver-interview-no-idea",
  "interview", "Complex", "2026-04-14",

  # Aaron Frazer (3)
  "I think I can bring people joy and light while also bringing them some place to feel mourning or anger, outrage, sadness. All those things.",
  "Aaron Frazer", "https://www.nepm.org/2021-01-10/on-introducing-aaron-frazer-contemplates-love-and-the-road-ahead",
  "interview", "NPR (Lulu Garcia-Navarro), January 2021", "2026-04-14",

  "Given that so many artists who have come before me, especially artists of color, have given me so much, I feel like I have a platform and I want to use it.",
  "Aaron Frazer", "https://www.nepm.org/2021-01-10/on-introducing-aaron-frazer-contemplates-love-and-the-road-ahead",
  "interview", "NPR, January 2021", "2026-04-14",

  "I'm many things, and I want to be able to show people the full dimension of myself and not worry about labels.",
  "Aaron Frazer", "https://glidemagazine.com/253145/aaron-frazer-of-durand-jones-the-indications-talks-new-solo-lp-working-with-dan-auerbach-classic-soul-inspiration-and-more-interview/",
  "interview", "Glide Magazine", "2026-04-14",

  # Post Malone (2)
  "Four years ago, I was on a rough path. It was terrible. Getting up, having a good cry, drinking, and then going living your life, and then whenever you go lay down, drinking some more and having a good cry.",
  "Post Malone", "https://www.rollingstone.com/music/music-news/post-malone-daughter-saved-life-1235078111/",
  "interview", "Rolling Stone, 2024", "2026-04-14",

  "I don't feel like that anymore, and it's the most amazing thing.",
  "Post Malone", "https://www.rollingstone.com/music/music-news/post-malone-daughter-saved-life-1235078111/",
  "interview", "Rolling Stone, 2024", "2026-04-14",

  # Mac Miller (3)
  "I think I'm in a different place than I thought I would be, but I think I'm in a place that Malcolm as a human being wanted.",
  "Mac Miller", "https://www.vulture.com/2018/09/mac-miller-swimming-interview.html",
  "interview", "Vulture (Craig Jenkins), September 2018", "2026-04-14",

  "My goal is trying to find some type of comfort. I think the last wish I made was for peace of mind, probably.",
  "Mac Miller", "https://www.vulture.com/2018/09/mac-miller-swimming-interview.html",
  "interview", "Vulture, September 2018", "2026-04-14",

  "No one's ever gonna really know me... and that's OK.",
  "Mac Miller", "https://www.vulture.com/2018/09/mac-miller-swimming-interview.html",
  "interview", "Vulture, September 2018", "2026-04-14",

  # Lil Yachty (4)
  "Who cares? It's going to go, or it's not. You only have one life, bro. Just do shit.",
  "Lil Yachty", "https://www.rollingstone.com/music/music-features/lil-yachty-lets-start-here-interview-psychedelics-1234691957/",
  "interview", "Rolling Stone (Let's Start Here)", "2026-04-14",

  "The more you give, the less cool something becomes. That's what I feel like is a problem with music nowadays. Everyone is oversharing.",
  "Lil Yachty", "https://www.rollingstone.com/music/music-features/lil-yachty-lets-start-here-interview-psychedelics-1234691957/",
  "interview", "Rolling Stone", "2026-04-14",

  "I don't need acceptance from nobody. People seek too much validation.",
  "Lil Yachty", "https://www.rollingstone.com/music/music-features/lil-yachty-lets-start-here-interview-psychedelics-1234691957/",
  "interview", "Rolling Stone", "2026-04-14",

  "They made me a man. They made me strong. They made me care more about the craft — because I do.",
  "Lil Yachty", "https://www.rollingstone.com/music/music-features/lil-yachty-lets-start-here-interview-psychedelics-1234691957/",
  "interview", "Rolling Stone", "2026-04-14",

  # Fre$h / Short Dawg (2)
  "As long as you keep working, keep working and keep working, you will get where you wanna go.",
  "Fre$h", "https://www.complex.com/music/a/complex/short-dawg-talks-young-moneys-future-surviving-def-jam-deal",
  "interview", "Complex", "2026-04-14",

  "I wasn't moving forward and I wasn't happy. My biggest disappointment was not coming out with an album.",
  "Fre$h", "https://www.complex.com/music/a/complex/short-dawg-talks-young-moneys-future-surviving-def-jam-deal",
  "interview", "Complex", "2026-04-14",

  # Mustard (4)
  "You can't be hot forever. Even the best in the game. You have to reinvent yourself. And that's what I did.",
  "Mustard", "https://www.billboard.com/music/rb-hip-hop/mustard-not-like-us-producer-cover-story-1235793061/",
  "interview", "Billboard cover (Not Like Us)", "2026-04-14",

  "I try to take it day by day because, honestly, these days, I don't know what's coming next. Sometimes, I look at what's happening and think, I can't believe this is real. So, I don't set limits or put a cap on it. It's really just about striving to be the best I can every single day.",
  "Mustard", "https://www.grammy.com/news/mustard-interview-producer-of-the-year-2025-grammys-kendrick-lamar",
  "interview", "GRAMMY.com, 2025", "2026-04-14",

  "There's going to be a time when nobody picks up your calls — soak this all in, and when that time comes, save your money. Don't panic.",
  "Mustard", "https://www.billboard.com/music/rb-hip-hop/mustard-not-like-us-producer-cover-story-1235793061/",
  "interview", "Billboard (recounting Timbaland's advice)", "2026-04-14",

  "I just contribute it to God, staying on the right path and being a good person, and it's all coming back tenfold.",
  "Mustard", "https://www.grammy.com/news/mustard-interview-producer-of-the-year-2025-grammys-kendrick-lamar",
  "interview", "GRAMMY.com, 2025", "2026-04-14",

  # IDK (4)
  "In prison, you have nothing but your mind. There's so many limitations to what you can do. Prison was the first time that I used that part of my brain: I made a plan to be a rapper, mapped it out and then actually executed it.",
  "IDK", "https://www.nme.com/blogs/nme-radar/idk-interview-is-he-real-2747070",
  "interview", "NME", "2026-04-14",

  "Ignorance is the best way for some people to learn. Listeners can equate IDK to making a mistake, doing something wrong and sometimes learning the hard way.",
  "IDK", "https://www.nme.com/blogs/nme-radar/idk-interview-is-he-real-2747070",
  "interview", "NME", "2026-04-14",

  "If you break down the way the world works, the way things need one another to work together, or if you even break down our anatomy — God is real.",
  "IDK", "https://www.nme.com/blogs/nme-radar/idk-interview-is-he-real-2747070",
  "interview", "NME", "2026-04-14",

  "Us as humans just haven't figured out how to care for one another and work together. We need to figure that out.",
  "IDK", "https://www.nme.com/blogs/nme-radar/idk-interview-is-he-real-2747070",
  "interview", "NME", "2026-04-14",

  # Joey Bada$$ (4)
  "I'd rather be underrated than overrated, because I always have this place to get to.",
  "Joey Bada$$", "https://www.complex.com/music/joey-badass-interview-new-album-paco-rabanne",
  "interview", "Complex", "2026-04-14",

  "It's not fast food. It's not something that keeps coming. I just need time. I'm talking about my life, talking about my experiences.",
  "Joey Bada$$", "https://www.complex.com/music/joey-badass-interview-new-album-paco-rabanne",
  "interview", "Complex", "2026-04-14",

  "Every time we lose somebody in this hip-hop game, it affects all of us. It's like, yo, that could've been me.",
  "Joey Bada$$", "https://www.complex.com/music/joey-badass-interview-new-album-paco-rabanne",
  "interview", "Complex", "2026-04-14",

  "I have so much people that are counting on me, and I have my brothers in the heavens who are looking down and giving me the additional strength that I need to keep going.",
  "Joey Bada$$", "https://www.thefader.com/2016/02/22/joey-badass-interview-nyu-lecture",
  "interview", "The FADER (NYU lecture)", "2026-04-14",

  # --- CLIMATE ---

  # Katharine Hayhoe (4)
  "Our future is still in our hands. The conclusion, the ending has not been written. Our choices make more of a difference today than they ever have.",
  "Katharine Hayhoe", "https://onbeing.org/programs/katharine-hayhoe-our-future-is-still-in-our-hands/",
  "interview", "On Being with Krista Tippett, 2021", "2026-04-14",

  "The bible is God's written word, and the universe is God's expressed word. By studying one or the other equally, we are studying God's work.",
  "Katharine Hayhoe", "https://onbeing.org/programs/katharine-hayhoe-our-future-is-still-in-our-hands/",
  "interview", "On Being, 2021", "2026-04-14",

  "The number one thing we can do is the exact thing that we're not doing: talk about it.",
  "Katharine Hayhoe", "https://www.ted.com/talks/katharine_hayhoe_the_most_important_thing_you_can_do_to_fight_climate_change_talk_about_it",
  "speech", "TEDWomen, 2018", "2026-04-14",

  "Just about every single person in the world already has the values they need to care about a changing climate. They just haven't connected the dots.",
  "Katharine Hayhoe", "https://www.ted.com/talks/katharine_hayhoe_the_most_important_thing_you_can_do_to_fight_climate_change_talk_about_it",
  "speech", "TEDWomen, 2018", "2026-04-14",

  # Michael Mann (3)
  "If you can lead people to despair, if you can convince people that it's too late to do anything, then they're no longer advocates for the action that's needed.",
  "Michael Mann", "https://www.rollingstone.com/politics/politics-features/michael-mann-the-new-climate-war-book-1110937/",
  "interview", "Rolling Stone (New Climate War), 2021", "2026-04-14",

  "The truth is bad enough.",
  "Michael Mann", "https://yaleclimateconnections.org/2023/09/renowned-climate-scientist-michael-e-mann-on-what-doomers-get-wrong/",
  "interview", "Yale Climate Connections, 2023 (Mann citing Stephen Schneider)", "2026-04-14",

  "There's no point beyond which we shouldn't keep trying to limit warming. Every fraction of a degree matters to the level of suffering climate disruption will rain down on us.",
  "Michael Mann", "https://yaleclimateconnections.org/2023/09/renowned-climate-scientist-michael-e-mann-on-what-doomers-get-wrong/",
  "interview", "Yale Climate Connections, 2023", "2026-04-14",

  # James Hansen (3)
  "It is time to stop waffling so much and say that the evidence is pretty strong that the greenhouse effect is here.",
  "James Hansen", "https://en.wikipedia.org/wiki/Senate_Hearing_of_James_E._Hansen_(1988)",
  "testimony", "Senate testimony, June 23 1988", "2026-04-14",

  "The earth is warmer in 1988 than at any time in the history of instrumental measurements. The global warming is now large enough that we can ascribe with a high degree of confidence a cause and effect relationship to the greenhouse effect.",
  "James Hansen", "https://en.wikipedia.org/wiki/Senate_Hearing_of_James_E._Hansen_(1988)",
  "testimony", "Senate testimony, June 23 1988", "2026-04-14",

  "Humans are now in charge of future climate.",
  "James Hansen", "https://www.goodreads.com/work/quotes/8527750-storms-of-my-grandchildren-the-truth-about-the-coming-climate-catastrop",
  "book", "Storms of My Grandchildren (Bloomsbury, 2009)", "2026-04-14",

  # Gavin Schmidt (3)
  "It's real. It's us. But we still have choices about how bad we let it get.",
  "Gavin Schmidt", "https://www.fatherly.com/health/nasa-climatologist-gavin-schmidt-interview",
  "interview", "Fatherly", "2026-04-14",

  "There's everything to play for and the choices that we have yet to make are the difference between things getting just a little bit worse or it getting very, very, very much worse.",
  "Gavin Schmidt", "https://www.fatherly.com/health/nasa-climatologist-gavin-schmidt-interview",
  "interview", "Fatherly", "2026-04-14",

  "While we don't individually have everything under control, collectively we can make our views and choices and values felt.",
  "Gavin Schmidt", "https://www.fatherly.com/health/nasa-climatologist-gavin-schmidt-interview",
  "interview", "Fatherly", "2026-04-14",

  # Kate Marvel (4)
  "We need courage, not hope. Grief, after all, is the cost of being alive. We are all fated to live lives shot through with sadness, and are not worth less for it. Courage is the resolve to do well without the assurance of a happy ending.",
  "Kate Marvel", "https://onbeing.org/blog/kate-marvel-we-need-courage-not-hope-to-face-climate-change/",
  "essay", "On Being (2018)", "2026-04-14",

  "The opposite of hope is not despair. It is grief. Even while resolving to limit the damage, we can mourn.",
  "Kate Marvel", "https://onbeing.org/blog/kate-marvel-we-need-courage-not-hope-to-face-climate-change/",
  "essay", "On Being (2018)", "2026-04-14",

  "Hope is a creature of privilege: we know that things will be lost, but it is comforting to believe that others will bear the brunt of it.",
  "Kate Marvel", "https://onbeing.org/blog/kate-marvel-we-need-courage-not-hope-to-face-climate-change/",
  "essay", "On Being (2018)", "2026-04-14",

  "Being a scientist means I believe in miracles. I live on one. We are improbable life on a perfect planet.",
  "Kate Marvel", "https://www.rollingstone.com/politics/politics-features/kate-marvel-climate-scientist-jeff-goodell-interview-1064266/",
  "interview", "Rolling Stone (Jeff Goodell)", "2026-04-14",

  # Kim Cobb (4)
  "The feeling of loss was worse because it was an avoidable loss. As scientists, we've been warning about this for decades. For me, it was a bellwether event.",
  "Kim Cobb", "https://yaleclimateconnections.org/2020/04/a-leading-scientists-transition-from-climate-science-to-solutions/",
  "interview", "Yale Climate Connections, 2020", "2026-04-14",

  "Corals that are bleached are not dead. It's an incredibly important distinction that seems to be completely lost on the public.",
  "Kim Cobb", "https://e360.yale.edu/features/from_mass_coral_bleaching_scientist_looks_for_lessons_kim_cobb_el_nino",
  "interview", "Yale Environment 360", "2026-04-14",

  "What you think reefs might be experiencing in 20 years, they're experiencing now.",
  "Kim Cobb", "https://e360.yale.edu/features/from_mass_coral_bleaching_scientist_looks_for_lessons_kim_cobb_el_nino",
  "interview", "Yale Environment 360", "2026-04-14",

  "We thought we might have had 10 or 20 years to figure this out. We don't, folks. We need answers right now.",
  "Kim Cobb", "https://e360.yale.edu/features/from_mass_coral_bleaching_scientist_looks_for_lessons_kim_cobb_el_nino",
  "interview", "Yale Environment 360", "2026-04-14",

  # Johan Rockström (4)
  "It is fundamentally about reconnecting the world economy to the biosphere.",
  "Johan Rockström", "https://news.mit.edu/2017/johan-rockstrom-framework-for-preserving-earth-resilience-0926",
  "lecture", "MIT News, 2017", "2026-04-14",

  "The Holocene is the only equilibrium of the planet that we know for certain can support humanity.",
  "Johan Rockström", "https://news.mit.edu/2017/johan-rockstrom-framework-for-preserving-earth-resilience-0926",
  "lecture", "MIT News, 2017", "2026-04-14",

  "Boundaries are set to avoid tipping points, to have a high chance to keep the planet in a state as close as possible to the Holocene, that allows it to maintain its resilience, stability, and life support capabilities.",
  "Johan Rockström", "https://earth.org/interview/towards-a-new-global-approach-to-safeguard-planet-earth-an-interview-with-johan-rockstrom/",
  "interview", "Earth.Org", "2026-04-14",

  "Half of our climate debt is hidden under the carpet of a forgiving planet.",
  "Johan Rockström", "https://earth.org/interview/towards-a-new-global-approach-to-safeguard-planet-earth-an-interview-with-johan-rockstrom/",
  "interview", "Earth.Org", "2026-04-14",

  # Susan Joy Hassol (4)
  "Words matter because they affect how we think, feel, and act.",
  "Susan Joy Hassol", "https://ncse.ngo/random-samples-susan-joy-hassol",
  "interview", "National Center for Science Education", "2026-04-14",

  "It's about making it personal, connecting with people on values, finding common ground.",
  "Susan Joy Hassol", "https://ncse.ngo/random-samples-susan-joy-hassol",
  "interview", "NCSE", "2026-04-14",

  "'Natural disasters' is not a good choice for extreme weather events exacerbated by climate disruption.",
  "Susan Joy Hassol", "https://ncse.ngo/random-samples-susan-joy-hassol",
  "interview", "NCSE", "2026-04-14",

  "We have the tools we need to tackle the climate challenge. The technologies are abundant and affordable.",
  "Susan Joy Hassol", "https://ncse.ngo/random-samples-susan-joy-hassol",
  "interview", "NCSE", "2026-04-14",

  # Naomi Oreskes (5)
  "Balance is a political concept, not a scientific one. It really has no place in science.",
  "Naomi Oreskes", "https://www.scientificamerican.com/blog/cross-check/merchants-of-doubt-author-slams-corrosive-climate-change-skepticism/",
  "interview", "Scientific American (Cross-Check)", "2026-04-14",

  "The tobacco industry was way ahead of the postmodernists. They were already deconstructing science in the 1950s.",
  "Naomi Oreskes", "https://www.scientificamerican.com/blog/cross-check/merchants-of-doubt-author-slams-corrosive-climate-change-skepticism/",
  "interview", "Scientific American", "2026-04-14",

  "It feels especially surreal to be attacked for trying to explain science.",
  "Naomi Oreskes", "https://www.scientificamerican.com/blog/cross-check/merchants-of-doubt-author-slams-corrosive-climate-change-skepticism/",
  "interview", "Scientific American", "2026-04-14",

  "It wasn't about trusting scientists; it was about trusting science as a process, an enterprise, or an activity.",
  "Naomi Oreskes", "https://news.harvard.edu/gazette/story/2019/10/in-why-trust-science-naomi-oreskes-explains-why-the-process-of-proof-is-worth-trusting/",
  "interview", "Harvard Gazette (Why Trust Science?)", "2026-04-14",

  "All people have values, and we always will have values. If you had scientists with no values, that would be truly scary.",
  "Naomi Oreskes", "https://news.harvard.edu/gazette/story/2019/10/in-why-trust-science-naomi-oreskes-explains-why-the-process-of-proof-is-worth-trusting/",
  "interview", "Harvard Gazette", "2026-04-14",

  # Katharine Wilkinson (5)
  "We unravel as one or regenerate as one.",
  "Katharine Wilkinson", "https://www.csuchico.edu/regenerativeagriculture/blog/wilkinson-keynote.shtml",
  "speech", "CSU Chico keynote (Regenerative Agriculture)", "2026-04-14",

  "To focus only on what we can do as individuals instead of what we can do together will mean failure.",
  "Katharine Wilkinson", "https://www.csuchico.edu/regenerativeagriculture/blog/wilkinson-keynote.shtml",
  "speech", "CSU Chico keynote", "2026-04-14",

  "The Feminist Climate Renaissance is not a revolution or a takeover or a war, but rather an upwelling of a better way to do climate-oriented work.",
  "Katharine Wilkinson", "https://grist.org/fix/arts-culture/6-experts-on-the-dawning-of-a-feminist-climate-renaissance/",
  "interview", "Grist", "2026-04-14",

  "I think about the feminine as the life-giving energy that circulates through the world.",
  "Katharine Wilkinson", "https://grist.org/fix/arts-culture/6-experts-on-the-dawning-of-a-feminist-climate-renaissance/",
  "interview", "Grist", "2026-04-14",

  "It's about working with the living systems of the planet rather than trying to conquer or wrangle them.",
  "Katharine Wilkinson", "https://grist.org/fix/arts-culture/6-experts-on-the-dawning-of-a-feminist-climate-renaissance/",
  "interview", "Grist", "2026-04-14",

  # Michael Oppenheimer (2)
  "People don't make decisions based on the facts. They're guided by looking to others whom they trust.",
  "Michael Oppenheimer", "https://www.princetonmagazine.com/michael-oppenheimer-and-the-end-of-the-climate-as-you-know-it/",
  "interview", "Princeton Magazine", "2026-04-14",

  "People are only going to deal with problems like this if they feel everybody else is going to deal with them, too.",
  "Michael Oppenheimer", "https://www.princetonmagazine.com/michael-oppenheimer-and-the-end-of-the-climate-as-you-know-it/",
  "interview", "Princeton Magazine", "2026-04-14",

  # Friederike Otto (3)
  "It's always those who are already suffering in some form in our societies who pay the highest price.",
  "Friederike Otto", "https://yaleclimateconnections.org/2025/05/inequality-magnifies-climate-impacts-worldwide-climate-scientist-writes-in-new-book/",
  "interview", "Yale Climate Connections (Climate Injustice), 2025", "2026-04-14",

  "Climate change is a problem we are all creating, but we are also all really important for the solution.",
  "Friederike Otto", "https://yaleclimateconnections.org/2025/05/inequality-magnifies-climate-impacts-worldwide-climate-scientist-writes-in-new-book/",
  "interview", "Yale Climate Connections, 2025", "2026-04-14",

  "We don't use just one model. We use several different ways to simulate a world that might have been without man-made climate change.",
  "Friederike Otto", "https://www.digitaltrends.com/outdoors/friederike-otto-angry-weather-book/",
  "interview", "Digital Trends (Angry Weather)", "2026-04-14",

  # Peter Kalmus (3)
  "I've personally concluded that continuing to mindlessly burn fossil fuels, knowing what I know, is unacceptable.",
  "Peter Kalmus", "https://peterkalmus.net/books/read-by-chapter-being-the-change/being-the-change-chapter-4-global-warming-the-outlook/",
  "book", "Being the Change (2017), Ch. 4", "2026-04-14",

  "I personally find it less stressful to face the reality of global warming and to begin responding appropriately.",
  "Peter Kalmus", "https://peterkalmus.net/books/read-by-chapter-being-the-change/being-the-change-chapter-3-global-warming-the-science/",
  "book", "Being the Change (2017), Ch. 3", "2026-04-14",

  "Humans aren't the problem. A particular human culture is the problem.",
  "Peter Kalmus", "https://peterkalmus.net/books/read-by-chapter-being-the-change/being-the-change-chapter-3-global-warming-the-science/",
  "book", "Being the Change (2017), Ch. 3", "2026-04-14",

  # Jennifer Francis (2)
  "The speed of the change is what is very disturbing to me because it's such an indicator of what's happening to the planet as a whole.",
  "Jennifer Francis", "https://e360.yale.edu/features/unusually_warm_arctic_climate_turmoil_jennifer_francis",
  "interview", "Yale Environment 360", "2026-04-14",

  "Pretty much all of the changes that we expect to see happen in the climate system have been occurring more rapidly than we expected.",
  "Jennifer Francis", "https://e360.yale.edu/features/unusually_warm_arctic_climate_turmoil_jennifer_francis",
  "interview", "Yale Environment 360", "2026-04-14",

  # Ben Santer (3)
  "There's no point in being a scientist if you're unwilling to defend the technical expertise that you have and the findings that you and your colleagues have gained.",
  "Ben Santer", "https://www.csldf.org/2017/12/26/perspectives-scientists-become-targets-ben-santer/",
  "interview", "Climate Science Legal Defense Fund", "2026-04-14",

  "It is gratifying to know that what we do really matters at this point in human history.",
  "Ben Santer", "https://www.csldf.org/2017/12/26/perspectives-scientists-become-targets-ben-santer/",
  "interview", "Climate Science Legal Defense Fund", "2026-04-14",

  "This is our responsibility as scientists — to understand what's going on in the climate system, why climate is changing, and what likely outcomes are if we do not significantly reduce emissions of greenhouse gases.",
  "Ben Santer", "https://www.csldf.org/2017/12/26/perspectives-scientists-become-targets-ben-santer/",
  "interview", "Climate Science Legal Defense Fund", "2026-04-14",

  # Richard Alley (3)
  "The more the climate is forced to change, the more likely it is to hit some unforeseen threshold that can trigger quite fast, surprising and perhaps unpleasant changes.",
  "Richard Alley", "https://www.heinzawards.org/pages/richard-alley",
  "interview", "Heinz Awards citation", "2026-04-14",

  "I don't see any fundamental barriers to us getting to a sustainable, peaceful, happy and healthy world except us.",
  "Richard Alley", "https://www.earthmagazine.org/article/down-earth-glaciologist-richard-alley/",
  "interview", "EARTH Magazine", "2026-04-14",

  "Climate science has now been demonstrated to be skillful. It does not tell you what policies to pass, but it is a piece of useful information with associated uncertainties.",
  "Richard Alley", "https://www.earthmagazine.org/article/down-earth-glaciologist-richard-alley/",
  "interview", "EARTH Magazine", "2026-04-14",

  # Bill McKibben (3)
  "We are the creature that can take notice and bear witness to the beauty of the world we inhabit. It seems a sin not to take that notice.",
  "Bill McKibben", "https://thejesuitpost.org/2022/10/bill-mckibben-we-must-learn-to-fit-back-inside-creation/",
  "interview", "The Jesuit Post, 2022", "2026-04-14",

  "We've been small and something else — God or nature — has been very large, and all of a sudden those proportions are reversed.",
  "Bill McKibben", "https://thejesuitpost.org/2022/10/bill-mckibben-we-must-learn-to-fit-back-inside-creation/",
  "interview", "The Jesuit Post, 2022", "2026-04-14",

  "The iron rule of climate change is the less you did to cause it, the more and the quicker you suffer.",
  "Bill McKibben", "https://e360.yale.edu/features/why-bill-mckibben-sees-rays-of-hope-in-a-grim-climate-picture",
  "interview", "Yale Environment 360", "2026-04-14",

  # David Wallace-Wells (3)
  "The size of those impacts are a measure of our own agency. We have the power to stop them from happening entirely.",
  "David Wallace-Wells", "https://www.rollingstone.com/politics/politics-news/the-strange-optimism-of-climate-alarmist-david-wallace-wells-807028/",
  "interview", "Rolling Stone", "2026-04-14",

  "That story is entirely up to us to write. Absolutely anything that could happen will only happen if we let it.",
  "David Wallace-Wells", "https://www.rollingstone.com/politics/politics-news/the-strange-optimism-of-climate-alarmist-david-wallace-wells-807028/",
  "interview", "Rolling Stone", "2026-04-14",

  "Whatever you think is a permanent, lasting, eternal feature of human life — all of it will be affected by climate change.",
  "David Wallace-Wells", "https://www.penguinrandomhouse.com/articles/the-uninhabitable-earth/",
  "interview", "Penguin Random House (Uninhabitable Earth)", "2026-04-14",

  # Elizabeth Kolbert (3)
  "The qualities that made us human to begin with — our restlessness, our creativity, our ability to cooperate to solve problems and complete complicated tasks — are leading us to rapidly transform the world.",
  "Elizabeth Kolbert", "https://www.nationalgeographic.com/science/article/140218-kolbert-book-extinction-climate-science-amazon-rain-forest-wilderness",
  "interview", "National Geographic (The Sixth Extinction)", "2026-04-14",

  "We are the asteroid now. The asteroid also had a lot of different effects, and it didn't end too well.",
  "Elizabeth Kolbert", "https://www.nationalgeographic.com/science/article/140218-kolbert-book-extinction-climate-science-amazon-rain-forest-wilderness",
  "interview", "National Geographic", "2026-04-14",

  "We have to be able to acknowledge that there's a lot of bad shit happening, and also that we have a responsibility to try to minimize that.",
  "Elizabeth Kolbert", "https://tricycle.org/magazine/no-easy-answers/",
  "interview", "Tricycle Magazine", "2026-04-14",

  # Ayana Elizabeth Johnson (3)
  "This is the work of our lifetime, so why don't we find ways to make it delightful?",
  "Ayana Elizabeth Johnson", "https://www.nosmallendeavor.com/ayana-elizabeth-johnson-what-if-we-get-climate-action-right",
  "interview", "No Small Endeavor", "2026-04-14",

  "Even if we don't get it right, I will have lived a much more rewarding life for having tried to get it right.",
  "Ayana Elizabeth Johnson", "https://www.nosmallendeavor.com/ayana-elizabeth-johnson-what-if-we-get-climate-action-right",
  "interview", "No Small Endeavor", "2026-04-14",

  "Instead of focusing on how to be hopeful, I think we can just focus on how to be useful.",
  "Ayana Elizabeth Johnson", "https://www.ted.com/pages/3-ways-to-fight-climate-change-without-getting-overwhelmed-transcript",
  "speech", "TED", "2026-04-14",
)

stopifnot(
  all(nchar(quotes$quote) > 0),
  all(nchar(quotes$author) > 0),
  all(grepl("^https?://", quotes$source)),
  !anyDuplicated(quotes$quote)
)

dir.create("inst/extdata", showWarnings = FALSE, recursive = TRUE)

utils::write.csv(
  quotes,
  file = "data-raw/quotes_audit.csv",
  row.names = FALSE,
  fileEncoding = "UTF-8"
)

utils::write.csv(
  quotes[, c("quote", "author", "source")],
  file = "inst/extdata/quotes.csv",
  row.names = FALSE,
  fileEncoding = "UTF-8"
)

message(sprintf("Wrote %d quotes to inst/extdata/quotes.csv and data-raw/quotes_audit.csv", nrow(quotes)))
