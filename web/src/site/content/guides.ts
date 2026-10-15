// The nine habit guides, one per habit the app tracks. Each becomes a page at
// /<slug> (for example /quit-smoking) and is linked from the home page.

export type Guide = {
  slug: string;
  label: string;
  habit: string;
  summary: string;
  title: string;
  metaTitle: string;
  metaDescription: string;
  intro: string;
  bullets: string[];
  sections: {
    title: string;
    body: string;
  }[];
  faq: {
    question: string;
    answer: string;
  }[];
  related: string[];
  keywords: string[];
};

export const guides: Guide[] = [
  {
    slug: "quit-smoking",
    label: "Quit Smoking",
    habit: "Smoking",
    summary: "Smoke-free days, cigarette cravings and the money you stop spending on packs.",
    title: "Quit Smoking With Streaks, Craving SOS, and Savings",
    metaTitle: "Quit Smoking App for iPhone | Quit All",
    metaDescription: "Quit smoking with an iPhone streak tracker, craving SOS GIFs, money saved, widgets, milestones, and relapse logging in Quit All.",
    intro: "Quit All helps you track smoke-free days, get through cigarette cravings, and see the money you are keeping instead of spending on packs.",
    bullets: [
      "Track your smoke-free streak from the moment you stop.",
      "Use SOS mode when a cigarette craving hits hard.",
      "See estimated money saved and long-term savings projections.",
      "Log slips without losing the progress you already made.",
    ],
    sections: [
      {
        title: "A cigarette craving tool built for the moment",
        body: "When the urge hits, the app gives you a timed SOS flow with GIFs, offline fallback loops, and short consequence reminders so you can ride out the next few minutes instead of negotiating with yourself.",
      },
      {
        title: "Progress that stays visible",
        body: "Home Screen and Lock Screen widgets keep your smoke-free streak visible without opening the app. Seeing the count repeatedly can make the decision to stay quit feel more concrete.",
      },
      {
        title: "Savings make quitting measurable",
        body: "Set what cigarettes usually cost you and Quit All turns every smoke-free day into visible savings. The app can show daily, monthly, yearly, and longer-term projections.",
      },
    ],
    faq: [
      {
        question: "Can Quit All help me stop smoking cigarettes?",
        answer: "Quit All can help you track smoke-free time, manage cravings, see savings, and restart after slips. It is not medical advice or a replacement for a clinician.",
      },
      {
        question: "Does the quit smoking tracker work offline?",
        answer: "Your streaks and local data stay on your iPhone. SOS content can use online GIFs when available and offline fallback loops when connection is poor.",
      },
      {
        question: "Can I track money saved from quitting smoking?",
        answer: "Yes. Add your typical cigarette spending and Quit All estimates how much money you have saved by staying smoke-free.",
      },
    ],
    related: ["quit-vaping", "quit-drinking", "quit-caffeine"],
    keywords: ["quit smoking app", "stop smoking tracker", "smoke free days", "cigarette craving help"],
  },
  {
    slug: "quit-vaping",
    label: "Quit Vaping",
    habit: "Vaping",
    summary: "Vape-free time down to the minute, and help when a nicotine urge spikes.",
    title: "Quit Vaping and Track Every Vape-Free Day",
    metaTitle: "Quit Vaping App for iPhone | Quit All",
    metaDescription: "Quit vaping with vape-free streaks, craving SOS GIFs, savings tracking, widgets, relapse logging, and motivation inside Quit All.",
    intro: "Quit All gives you a focused place to track vape-free time, get through nicotine urges, and make progress visible on your iPhone.",
    bullets: [
      "Track days, hours, and minutes since your last vape.",
      "Use SOS mode when nicotine cravings spike.",
      "Estimate what pods, disposables, or refills used to cost.",
      "Keep progress visible with iPhone widgets.",
    ],
    sections: [
      {
        title: "Built for quick nicotine urges",
        body: "Vape cravings can arrive fast and feel automatic. Quit All puts a quick SOS button in the app so you have something to do immediately when your brain asks for one more hit.",
      },
      {
        title: "Replace vague progress with real numbers",
        body: "The app shows your vape-free streak, relapse history, and savings so the work you are doing is not invisible. Small wins become easier to notice.",
      },
      {
        title: "Helpful without public posting",
        body: "Quit All does not require an account or social feed. Your habit data is meant to stay private on your device while Apple and RevenueCat handle purchases.",
      },
    ],
    faq: [
      {
        question: "Can I use Quit All as a vape-free counter?",
        answer: "Yes. Quit All tracks the time since your last vape and can keep that progress visible in the app and on supported iPhone widgets.",
      },
      {
        question: "Does it track nicotine cravings?",
        answer: "You can use SOS sessions during cravings and review patterns over time with premium stats and reminders.",
      },
      {
        question: "Can I track both smoking and vaping?",
        answer: "Yes. Quit All supports multiple habits, so you can track smoking and vaping separately in one app.",
      },
    ],
    related: ["quit-smoking", "quit-caffeine", "digital-detox"],
    keywords: ["quit vaping app", "stop vaping", "vape free tracker", "nicotine craving app"],
  },
  {
    slug: "quit-drinking",
    label: "Quit Drinking",
    habit: "Alcohol",
    summary: "Sober days, alcohol-free milestones and the money you keep.",
    title: "Quit Drinking With a Private Sober Day Tracker",
    metaTitle: "Quit Drinking App and Sober Counter | Quit All",
    metaDescription: "Track sober days, alcohol-free streaks, craving moments, milestones, and money saved with the Quit All iPhone app.",
    intro: "Quit All helps you count alcohol-free days, notice danger times, and keep your sober progress private on your iPhone.",
    bullets: [
      "Track sober days and alcohol-free streaks.",
      "Use SOS mode during urges to drink.",
      "Estimate money saved from not buying alcohol.",
      "Review patterns around cravings and relapses.",
    ],
    sections: [
      {
        title: "A sober counter without a social feed",
        body: "The app focuses on your private progress, not public posting. You can track sober time, milestones, and savings without creating an account.",
      },
      {
        title: "Cravings are time-sensitive",
        body: "SOS mode is designed for the first few minutes of an urge. It gives you motion, reminders, and a timed pause so you can make it through the peak.",
      },
      {
        title: "Learn from slips without shame",
        body: "If you drink again, you can log it and keep the history. The goal is to learn patterns and restart instead of pretending progress disappeared.",
      },
    ],
    faq: [
      {
        question: "Is Quit All a sobriety app?",
        answer: "Quit All can be used as a private sober day tracker for alcohol-free streaks, cravings, milestones, and savings.",
      },
      {
        question: "Does Quit All replace alcohol treatment?",
        answer: "No. Quit All is a tracking and motivation tool. If alcohol withdrawal or safety is a concern, talk to a medical professional.",
      },
      {
        question: "Can I track money saved from not drinking?",
        answer: "Yes. Enter your usual alcohol spending and the app estimates the savings from your alcohol-free days.",
      },
    ],
    related: ["quit-smoking", "quit-weed", "stop-overspending"],
    keywords: ["quit drinking app", "sober counter", "sobriety tracker", "alcohol free tracker"],
  },
  {
    slug: "quit-weed",
    label: "Quit Weed",
    habit: "Weed",
    summary: "Weed-free days, cravings and the time and money you take back.",
    title: "Quit Weed and Track Cannabis-Free Progress",
    metaTitle: "Quit Weed App and Cannabis-Free Tracker | Quit All",
    metaDescription: "Track weed-free days, cravings, money saved, milestones, relapse history, and widgets with Quit All for iPhone.",
    intro: "Quit All helps you track days without weed, get through cravings, and understand the money and time you are taking back.",
    bullets: [
      "Track cannabis-free streaks privately.",
      "Use SOS mode when the urge to smoke appears.",
      "See money saved from skipping weed purchases.",
      "Track other habits alongside weed if needed.",
    ],
    sections: [
      {
        title: "Make weed-free progress visible",
        body: "A clear streak gives you a reference point when cravings make progress feel abstract. Quit All keeps that count available in the app and widgets.",
      },
      {
        title: "Use one place for related habits",
        body: "People often work on weed, vaping, social media, or spending at the same time. Quit All supports multiple habit tracks so you do not need separate apps.",
      },
      {
        title: "Private by default",
        body: "Quit All does not require an account. Your habit data is meant to stay local to your iPhone, with purchases handled by Apple and RevenueCat.",
      },
    ],
    faq: [
      {
        question: "Can I use Quit All as a weed-free day counter?",
        answer: "Yes. Quit All can track your weed-free streak and help you log cravings, milestones, relapses, and savings.",
      },
      {
        question: "Does it support quitting smoking weed and vaping?",
        answer: "Yes. You can track weed and vaping as separate habits in the same app.",
      },
      {
        question: "Is my quit weed history public?",
        answer: "No. Quit All is built as a private tracker and does not require an account or public profile.",
      },
    ],
    related: ["quit-vaping", "quit-smoking", "digital-detox"],
    keywords: ["quit weed app", "weed free tracker", "cannabis quit tracker", "stop smoking weed"],
  },
  {
    slug: "stop-gambling",
    label: "Stop Gambling",
    habit: "Gambling",
    summary: "Gambling-free days and a pause before the next bet or deposit.",
    title: "Stop Gambling With Urge Support and Savings Tracking",
    metaTitle: "Stop Gambling App and Urge Tracker | Quit All",
    metaDescription: "Track gambling-free days, urges, relapse history, money saved, milestones, and reminders with Quit All for iPhone.",
    intro: "Quit All gives you a private place to count gambling-free days, interrupt urges, and see how much money you are protecting.",
    bullets: [
      "Track gambling-free streaks and relapse history.",
      "Use SOS mode during betting or casino urges.",
      "Estimate money saved by not gambling.",
      "Review danger times with premium stats.",
    ],
    sections: [
      {
        title: "Interrupt the urge before action",
        body: "A gambling urge can turn into a deposit or bet quickly. SOS mode creates friction and gives you a timed alternative before you act.",
      },
      {
        title: "See money protected",
        body: "Quit All can estimate the money you have not spent on gambling. That number makes the benefit of staying away easier to see.",
      },
      {
        title: "Track patterns over time",
        body: "Premium stats can help you notice when urges are most common, so reminders can be scheduled around higher-risk moments.",
      },
    ],
    faq: [
      {
        question: "Can Quit All help me stop gambling?",
        answer: "Quit All can help track gambling-free time, cravings, savings, and slips. It is a support tool, not a substitute for professional help.",
      },
      {
        question: "Can I track money saved from not gambling?",
        answer: "Yes. Add an estimated amount and the app can show savings over time.",
      },
      {
        question: "Does Quit All include blockers?",
        answer: "Quit All focuses on tracking, SOS craving support, reminders, and progress visibility. Use dedicated blocking tools if you need device or account blocks.",
      },
    ],
    related: ["stop-overspending", "digital-detox", "quit-drinking"],
    keywords: ["stop gambling app", "gambling tracker", "gambling urge tracker", "gambling free days"],
  },
  {
    slug: "stop-overspending",
    label: "Stop Overspending",
    habit: "Overspending",
    summary: "No-spend streaks and a pause before an impulse purchase.",
    title: "Stop Overspending and Track Money Saved",
    metaTitle: "Stop Overspending App and Savings Tracker | Quit All",
    metaDescription: "Track spending-free streaks, urges to buy, money saved, milestones, and relapse history with Quit All for iPhone.",
    intro: "Quit All helps you count days without impulse purchases, pause during buying urges, and see the money you keep.",
    bullets: [
      "Track no-spend streaks and impulse-buying slips.",
      "Use SOS mode before a purchase you might regret.",
      "See savings grow over time.",
      "Track overspending alongside other habits.",
    ],
    sections: [
      {
        title: "Create a pause before buying",
        body: "Impulse spending often happens in a short window. Quit All gives you a button to press during that window so you can slow the decision down.",
      },
      {
        title: "Turn avoided purchases into progress",
        body: "A no-spend streak and savings estimate can make restraint feel less invisible. The app shows what you are preserving each day.",
      },
      {
        title: "Works with related habits",
        body: "Overspending can connect with gambling, caffeine, social media, or stress routines. Quit All lets you track multiple patterns in one place.",
      },
    ],
    faq: [
      {
        question: "Can Quit All track no-spend days?",
        answer: "Yes. You can use Quit All to track overspending-free streaks and estimate money saved.",
      },
      {
        question: "Can I use SOS mode before buying something?",
        answer: "Yes. SOS mode can be used for any urge, including an impulse purchase you want to delay.",
      },
      {
        question: "Can I track overspending and gambling separately?",
        answer: "Yes. Quit All supports multiple habit tracks, including overspending and gambling.",
      },
    ],
    related: ["stop-gambling", "digital-detox", "quit-caffeine"],
    keywords: ["stop overspending app", "no spend tracker", "impulse spending tracker", "money saved app"],
  },
  {
    slug: "quit-caffeine",
    label: "Quit Caffeine",
    habit: "Caffeine",
    summary: "Coffee-free or caffeine-free days and what the daily drinks cost.",
    title: "Quit Caffeine and Count Caffeine-Free Days",
    metaTitle: "Quit Caffeine App and Coffee-Free Tracker | Quit All",
    metaDescription: "Track caffeine-free days, coffee cravings, energy drink spending, milestones, relapses, and widgets with Quit All.",
    intro: "Quit All helps you track days without caffeine, coffee, or energy drinks and see the money saved from changing the habit.",
    bullets: [
      "Count caffeine-free or coffee-free streaks.",
      "Use SOS mode during coffee or energy drink cravings.",
      "Track money saved from skipping daily drinks.",
      "Keep progress visible with iPhone widgets.",
    ],
    sections: [
      {
        title: "A simple caffeine-free counter",
        body: "Set your quit date and Quit All starts counting. You can use it for coffee, energy drinks, soda, or any caffeine routine you want to stop.",
      },
      {
        title: "Savings add up fast",
        body: "Daily coffee or energy drink purchases can quietly become expensive. Quit All turns skipped purchases into visible savings.",
      },
      {
        title: "Track alongside nicotine or alcohol",
        body: "If caffeine is one of several habits you are changing, Quit All keeps them together so your progress is easier to review.",
      },
    ],
    faq: [
      {
        question: "Can I use Quit All to quit coffee?",
        answer: "Yes. You can track coffee-free or caffeine-free days, cravings, relapses, and savings.",
      },
      {
        question: "Does Quit All provide medical advice about caffeine withdrawal?",
        answer: "No. Quit All is a tracker and motivation tool. For medical questions, ask a qualified health professional.",
      },
      {
        question: "Can I track money saved from quitting caffeine?",
        answer: "Yes. Add your usual caffeine spending and Quit All estimates savings over time.",
      },
    ],
    related: ["quit-vaping", "quit-smoking", "stop-overspending"],
    keywords: ["quit caffeine app", "coffee free tracker", "caffeine free days", "energy drink tracker"],
  },
  {
    slug: "digital-detox",
    label: "Digital Detox",
    habit: "Social media",
    summary: "Days without compulsive scrolling, and something to do instead of opening the app.",
    title: "Digital Detox Tracking for Social Media and Scrolling",
    metaTitle: "Digital Detox App for Social Media Habits | Quit All",
    metaDescription: "Track social media breaks, scrolling urges, screen time habits, milestones, relapses, and progress widgets with Quit All.",
    intro: "Quit All helps you track days without compulsive scrolling, social media loops, or other screen-time habits you want to break.",
    bullets: [
      "Track social-media-free or scrolling-free streaks.",
      "Use SOS mode when the urge to open an app hits.",
      "Review relapse patterns and danger times.",
      "Keep your detox private without an account.",
    ],
    sections: [
      {
        title: "Designed for the urge to open one more app",
        body: "The app gives you something else to do in the exact moment you want to scroll. That pause can be enough to keep the streak alive.",
      },
      {
        title: "Track behavior, not just screen time",
        body: "Screen time totals are useful, but Quit All focuses on the habit you are trying to break. You can track the streak and slips around a specific platform or pattern.",
      },
      {
        title: "Pair digital detox with other habits",
        body: "Social media can connect with porn, spending, gambling, or sleep routines. Quit All lets you track several habits together instead of scattering data across apps.",
      },
    ],
    faq: [
      {
        question: "Can Quit All help with social media addiction?",
        answer: "Quit All can track social-media-free streaks, urges, relapses, and progress. It does not block apps by itself.",
      },
      {
        question: "Is this a screen time blocker?",
        answer: "No. Quit All is a private tracker and SOS tool. Use Apple's Screen Time controls if you need hard app limits.",
      },
      {
        question: "Can I track multiple digital habits?",
        answer: "Yes. You can track social media and other habits separately in the same app.",
      },
    ],
    related: ["quit-porn", "stop-overspending", "quit-vaping"],
    keywords: ["digital detox app", "social media addiction tracker", "scrolling habit tracker", "screen time habit"],
  },
  {
    slug: "quit-porn",
    label: "Quit Porn",
    habit: "Porn",
    summary: "Porn-free days, tracked privately, with support when an urge starts.",
    title: "Quit Porn With a Private Streak and Urge Tracker",
    metaTitle: "Quit Porn App and Private Streak Tracker | Quit All",
    metaDescription: "Track porn-free days, urges, relapse history, milestones, and private progress with Quit All for iPhone.",
    intro: "Quit All gives you a private place to track porn-free days, use SOS support during urges, and restart without shame after slips.",
    bullets: [
      "Track porn-free streaks privately.",
      "Use SOS mode during urges.",
      "Log slips without deleting your history.",
      "Track digital habits alongside other patterns.",
    ],
    sections: [
      {
        title: "Private tracking without an account",
        body: "Quit All is built for people who want a quiet, private way to track progress. No public feed or account is required.",
      },
      {
        title: "A tool for urge moments",
        body: "SOS mode gives you a timed alternative when an urge starts. It is designed to help you get through the next few minutes.",
      },
      {
        title: "Keep the whole pattern visible",
        body: "You can track porn together with social media, overspending, or other habits that show up around the same times.",
      },
    ],
    faq: [
      {
        question: "Can Quit All track porn-free days?",
        answer: "Yes. Quit All can track porn-free streaks, urges, milestones, and relapse history privately.",
      },
      {
        question: "Does Quit All block adult websites?",
        answer: "No. Quit All is a tracker and SOS support tool. Use dedicated blocking or Screen Time tools if you need hard blocks.",
      },
      {
        question: "Is my quit porn progress public?",
        answer: "No. Quit All does not require a public profile or account.",
      },
    ],
    related: ["digital-detox", "stop-overspending", "quit-weed"],
    keywords: ["quit porn app", "porn free tracker", "private addiction tracker", "urge tracker"],
  },
];

export const guideMap = new Map(guides.map((page) => [page.slug, page]));
