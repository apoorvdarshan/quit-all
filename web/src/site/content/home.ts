import { APP_STORE_URL, PRICES } from "./site.ts";

// The habits in the order the app lists them, as guide slugs.
export const habitOrder = [
  "quit-smoking",
  "quit-vaping",
  "quit-drinking",
  "quit-porn",
  "digital-detox",
  "quit-weed",
  "stop-gambling",
  "stop-overspending",
  "quit-caffeine",
] as const;

export const screens = [
  {
    src: "/ss-onboarding.jpg",
    alt: "Quit All onboarding screen for choosing the habits to quit",
    caption: "Pick the habits you're quitting. One or all nine.",
  },
  {
    src: "/ss-home.jpg",
    alt: "Quit All home screen showing 16 minutes clean from smoking",
    caption: "Your count starts at minutes and keeps going.",
  },
  {
    src: "/ss-sos-klipy.jpg",
    alt: "Quit All SOS screen with a five-minute timer and a GIF powered by KLIPY",
    caption: "Press I'm craving and a five-minute timer starts, with GIFs to watch.",
  },
  {
    src: "/ss-sos-offline.jpg",
    alt: "Quit All SOS screen playing an offline video loop with a roast caption",
    caption: "No signal? Offline video loops still play.",
  },
  {
    src: "/ss-stats-new.jpg",
    alt: "Quit All stats screen with craving patterns",
    caption: "See when cravings hit, so you can plan around them.",
  },
] as const;

export const features = [
  {
    title: "Streaks and widgets",
    body: "Clean time for every habit, on your Home Screen and Lock Screen without opening the app.",
  },
  {
    title: "Money kept",
    body: "Tell it what the habit cost you. It shows what you've saved and projects up to five years ahead.",
  },
  {
    title: "Craving patterns",
    body: "Hourly heatmaps and trigger breakdowns show when urges hit, and reminders arrive before your riskiest hours.",
  },
  {
    title: "Milestones",
    body: "Nine milestones, each with a health fact and a card you can share.",
  },
  {
    title: "Relapse without shame",
    body: "Log a slip with what happened and how you feel. Your history stays and the count restarts.",
  },
  {
    title: "Private by default",
    body: "No account, no login, no ads. Your habit data stays on your iPhone.",
  },
] as const;

export const plans = [
  {
    name: "Weekly",
    price: PRICES.weekly,
    period: "per week",
    note: "7-day free trial when eligible.",
    best: false,
  },
  {
    name: "Yearly",
    price: PRICES.yearly,
    period: "per year",
    note: "About $2.92 a month, 90% less than paying weekly. 7-day free trial when eligible.",
    best: true,
  },
  {
    name: "Lifetime",
    price: PRICES.lifetime,
    period: "once",
    note: "One payment. No renewal.",
    best: false,
  },
] as const;

export const faqs = [
  {
    q: "What is Quit All?",
    a: "Quit All is a private iPhone app for quitting multiple habits at once — smoking, vaping, alcohol, porn, social media, weed, gambling, overspending, and caffeine. It tracks your streaks, helps you survive cravings with an SOS mode (GIFs and offline video loops), shows the money you're saving, and lets you log relapses without shame.",
  },
  {
    q: "Is Quit All the same as AllQuit or Quitall?",
    a: "Yes. Quit All is sometimes searched as “AllQuit,” “Quitall,” or “all quit” — they all refer to the same app: Quit All - Break Every Habit on the App Store.",
  },
  {
    q: "What habits can I quit with Quit All?",
    a: "You can track quitting smoking, vaping, alcohol, porn, social media, weed, gambling, overspending, and caffeine — individually or several at the same time, each with its own streak, savings, and craving history.",
  },
  {
    q: "Is Quit All free?",
    a: "Quit All is free to download. Premium unlocks the full experience and includes a 7-day free trial on the Weekly and Yearly plans when eligible, plus a one-time Lifetime option. You can cancel anytime in your Apple ID settings.",
  },
  {
    q: "Does Quit All work offline?",
    a: "Yes. Your streaks and habit data are stored on your device, so the app works without a connection. During a craving, SOS mode uses online GIFs when available and falls back to bundled offline video loops when you have no signal.",
  },
  {
    q: "Is my data private?",
    a: "Yes. Quit All requires no account or login, and your habit data stays on your iPhone. There's no ad tracking, and your habit data is never sold. Purchases are handled by Apple.",
  },
] as const;

// Real lines from the app's meme library (ios/Quit All/Memes/MemeData.swift),
// shown by the craving button on the home page.
export const cravingLines = [
  { text: "The 'just one more' lie has killed more streaks than anything", kind: "Roast", habit: "Smoking and vaping" },
  { text: "Your lungs right now: 'Finally, some fresh air'", kind: "Motivation", habit: "Smoking and vaping" },
  { text: "Your sense of smell is coming back. Enjoy it.", kind: "Motivation", habit: "Smoking and vaping" },
  { text: "Your dentist is throwing a party right now", kind: "Roast", habit: "Smoking and vaping" },
  { text: "When someone lights up near you and it smells TERRIBLE now", kind: "Relatable", habit: "Smoking and vaping" },
  { text: "Sunday morning without a hangover hits different", kind: "Motivation", habit: "Alcohol" },
  { text: "You're not missing out. You're opting in to real life.", kind: "Motivation", habit: "Alcohol" },
  { text: "Realizing your whole weekend used to be structured around when and where you could drink", kind: "Relatable", habit: "Alcohol" },
  { text: "You refreshed the same app 47 times today. Nothing changed.", kind: "Roast", habit: "Social media" },
  { text: "Your attention is the most valuable thing you own. Stop giving it away.", kind: "Motivation", habit: "Social media" },
  { text: "You were 'chilling' so hard you forgot to live", kind: "Roast", habit: "Weed" },
  { text: "REM sleep hits different when you actually dream again", kind: "Motivation", habit: "Weed" },
  { text: "You walked away from the table and that took more guts than any bet", kind: "Motivation", habit: "Gambling" },
  { text: "You are more powerful than a push notification from a sale you did not need", kind: "Motivation", habit: "Overspending" },
  { text: "Every purchase you delayed and forgot about proves the want was not actually real", kind: "Motivation", habit: "Overspending" },
  { text: "You made it through the morning without it and that is not a small thing at all", kind: "Motivation", habit: "Caffeine" },
  { text: "Step outside and walk for 10 minutes. The urge won't survive it.", kind: "Distraction", habit: "Porn" },
  { text: "Cook something complicated. The focus kills the craving.", kind: "Distraction", habit: "Alcohol" },
  { text: "The 'I'll just have one' lie that has a 0% success rate", kind: "Relatable", habit: "Alcohol" },
] as const;

export const appStoreUrl = APP_STORE_URL;
