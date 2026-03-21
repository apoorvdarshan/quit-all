import Foundation

// MARK: - Meme Data
// Static motivational / roast / relatable text content per addiction type.

struct MemeItem: Identifiable {
    let id = UUID()
    let text: String
    let category: MemeCategory
    let addictionType: String
}

enum MemeCategory: String, CaseIterable {
    case motivational = "Motivational"
    case roast = "Roast"
    case consequence = "Consequence"
    case distraction = "Distraction"
    case relatable = "Relatable"

    var emoji: String {
        switch self {
        case .motivational: return "💪"
        case .roast: return "🔥"
        case .consequence: return "⚠️"
        case .distraction: return "🎭"
        case .relatable: return "😂"
        }
    }
}

// MARK: - Curated Meme Library
struct MemeDataLibrary {

    static func textMemes(for type: AddictionType) -> [MemeItem] {
        switch type {
        case .smoking, .vaping:
            return [
                MemeItem(text: "Your lungs right now: 'Finally, some fresh air'", category: .motivational, addictionType: type.rawValue),
                MemeItem(text: "POV: You smell like a person now, not an ashtray", category: .roast, addictionType: type.rawValue),
                MemeItem(text: "Your wallet seeing you walk past the tobacco store", category: .relatable, addictionType: type.rawValue),
                MemeItem(text: "Cigarette companies when you quit: 'Wait, that's illegal'", category: .distraction, addictionType: type.rawValue),
                MemeItem(text: "Every cigarette you DON'T smoke adds 11 minutes to your life", category: .consequence, addictionType: type.rawValue),
                MemeItem(text: "Your future kids thanking you for not smelling like smoke", category: .motivational, addictionType: type.rawValue),
                MemeItem(text: "You're not 'taking a break'. You're quitting. Own it.", category: .roast, addictionType: type.rawValue),
                MemeItem(text: "Day 1 you: 'I can't do this' — Day 30 you: 'I really did that'", category: .relatable, addictionType: type.rawValue),
                MemeItem(text: "Your teeth going from yellow to white: character development", category: .distraction, addictionType: type.rawValue),
                MemeItem(text: "Smoking doesn't reduce stress. It creates it, then temporarily pauses it.", category: .consequence, addictionType: type.rawValue),
                MemeItem(text: "Plot twist: You're stronger than a craving that lasts 3 minutes", category: .motivational, addictionType: type.rawValue),
                MemeItem(text: "Imagine explaining to your lungs why you lit them on fire again", category: .roast, addictionType: type.rawValue),
                MemeItem(text: "The 'just one more' lie has killed more streaks than anything", category: .consequence, addictionType: type.rawValue),
                MemeItem(text: "Your cardio improving: 'Is this what breathing feels like?!'", category: .relatable, addictionType: type.rawValue),
                MemeItem(text: "3 minutes. That's how long a craving lasts. You've survived worse.", category: .distraction, addictionType: type.rawValue),
            ]
        case .alcohol:
            return [
                MemeItem(text: "Sunday morning without a hangover hits different", category: .motivational, addictionType: type.rawValue),
                MemeItem(text: "Your liver writing you a thank you note", category: .roast, addictionType: type.rawValue),
                MemeItem(text: "POV: You remember last night because you were sober", category: .relatable, addictionType: type.rawValue),
                MemeItem(text: "Bank account after a month of not drinking: 'We're rich!'", category: .distraction, addictionType: type.rawValue),
                MemeItem(text: "Alcohol: Making bad decisions seem genius since forever", category: .consequence, addictionType: type.rawValue),
                MemeItem(text: "Waking up hydrated and shame-free is elite", category: .motivational, addictionType: type.rawValue),
                MemeItem(text: "Your drunk alter ego: 'Please bring me back' — You: 'No.'", category: .roast, addictionType: type.rawValue),
                MemeItem(text: "Remember: nobody ever regretted NOT drinking last night", category: .relatable, addictionType: type.rawValue),
                MemeItem(text: "Your skin clearing up because your body isn't fighting poison anymore", category: .distraction, addictionType: type.rawValue),
                MemeItem(text: "Alcohol is just borrowing happiness from tomorrow", category: .consequence, addictionType: type.rawValue),
                MemeItem(text: "Sober you makes decisions drunk you could never", category: .motivational, addictionType: type.rawValue),
                MemeItem(text: "'I'm more fun when I drink' — said every unfun person ever", category: .roast, addictionType: type.rawValue),
                MemeItem(text: "Imagine all the drunk texts you'll never have to apologize for", category: .relatable, addictionType: type.rawValue),
                MemeItem(text: "Your sleep quality went from 2/10 to 9/10. That's the sober glow up.", category: .distraction, addictionType: type.rawValue),
                MemeItem(text: "Your brain cells are literally regenerating right now", category: .consequence, addictionType: type.rawValue),
            ]
        case .porn:
            return [
                MemeItem(text: "Brain fog clearing after a week: 'I can see clearly now'", category: .motivational, addictionType: type.rawValue),
                MemeItem(text: "Touch grass. Seriously. Go outside.", category: .roast, addictionType: type.rawValue),
                MemeItem(text: "Your dopamine receptors healing: 'Is this what normal feels like?'", category: .relatable, addictionType: type.rawValue),
                MemeItem(text: "Real connections > pixels. Every time.", category: .distraction, addictionType: type.rawValue),
                MemeItem(text: "Your future self is thanking you right now", category: .consequence, addictionType: type.rawValue),
                MemeItem(text: "Day 7: You start noticing real beauty in the world again", category: .motivational, addictionType: type.rawValue),
                MemeItem(text: "Your brain on day 1 vs day 30: literally different organ", category: .roast, addictionType: type.rawValue),
                MemeItem(text: "The confidence boost from self-control is unmatched", category: .relatable, addictionType: type.rawValue),
                MemeItem(text: "Your attention span coming back is the real glow up", category: .distraction, addictionType: type.rawValue),
                MemeItem(text: "Every urge you beat makes your brain stronger. That's neuroscience.", category: .consequence, addictionType: type.rawValue),
                MemeItem(text: "You're rewiring your brain right now. That's not nothing.", category: .motivational, addictionType: type.rawValue),
                MemeItem(text: "You're choosing reality over fantasy. That takes courage.", category: .roast, addictionType: type.rawValue),
                MemeItem(text: "Social skills +100 when you stop frying your dopamine", category: .relatable, addictionType: type.rawValue),
                MemeItem(text: "Eyes up. Phone down. Life on.", category: .distraction, addictionType: type.rawValue),
                MemeItem(text: "Discipline is the bridge between who you are and who you want to be", category: .consequence, addictionType: type.rawValue),
            ]
        case .socialMedia:
            return [
                MemeItem(text: "Screen time report: -4 hours. Your eyes: THANK YOU", category: .motivational, addictionType: type.rawValue),
                MemeItem(text: "Nobody's life is as perfect as their Instagram", category: .roast, addictionType: type.rawValue),
                MemeItem(text: "POV: You looked up from your phone and it's been 3 seasons", category: .relatable, addictionType: type.rawValue),
                MemeItem(text: "Your attention span coming back: 'I can focus for 10 whole minutes!'", category: .distraction, addictionType: type.rawValue),
                MemeItem(text: "FOMO is fake. JOMO (Joy of Missing Out) is real.", category: .consequence, addictionType: type.rawValue),
                MemeItem(text: "You didn't miss anything important on social media today. Trust me.", category: .motivational, addictionType: type.rawValue),
                MemeItem(text: "Doom scrolling is just depression with extra steps", category: .roast, addictionType: type.rawValue),
                MemeItem(text: "Your brain after not scrolling for 1 hour: 'I had a thought!'", category: .relatable, addictionType: type.rawValue),
                MemeItem(text: "The algorithm doesn't care about you. Your real life does.", category: .distraction, addictionType: type.rawValue),
                MemeItem(text: "Average screen time: 7 hours/day. That's 106 days/year staring at a phone.", category: .consequence, addictionType: type.rawValue),
                MemeItem(text: "You're not staying 'connected'. You're staying distracted.", category: .motivational, addictionType: type.rawValue),
                MemeItem(text: "Notifications are just a corporation interrupting your life", category: .roast, addictionType: type.rawValue),
                MemeItem(text: "Read a book. Touch grass. Call a friend. Any of these beats scrolling.", category: .relatable, addictionType: type.rawValue),
                MemeItem(text: "Your creativity comes back when you stop consuming and start creating", category: .distraction, addictionType: type.rawValue),
                MemeItem(text: "Comparison is the thief of joy — and social media is the delivery service", category: .consequence, addictionType: type.rawValue),
            ]
        case .weed:
            return [
                MemeItem(text: "REM sleep hits different when you actually dream again", category: .motivational, addictionType: type.rawValue),
                MemeItem(text: "'I can quit anytime' — said everyone who couldn't quit", category: .roast, addictionType: type.rawValue),
                MemeItem(text: "Your short-term memory making a comeback", category: .relatable, addictionType: type.rawValue),
                MemeItem(text: "Energy levels after quitting: 'So THIS is what motivation feels like'", category: .distraction, addictionType: type.rawValue),
                MemeItem(text: "Your bank account when you stop buying at dispensary prices", category: .consequence, addictionType: type.rawValue),
                MemeItem(text: "Emotions hitting different when you're not numbing them 24/7", category: .motivational, addictionType: type.rawValue),
                MemeItem(text: "Couch locked at 2pm on a Tuesday is not 'self care'", category: .roast, addictionType: type.rawValue),
                MemeItem(text: "Your lungs, your wallet, and your ambition all agree: quit.", category: .relatable, addictionType: type.rawValue),
                MemeItem(text: "Sobriety isn't boring. You were just too high to notice life.", category: .distraction, addictionType: type.rawValue),
                MemeItem(text: "Weed doesn't help anxiety. It hides it until it doesn't.", category: .consequence, addictionType: type.rawValue),
                MemeItem(text: "Your appetite normalizing is a whole journey", category: .motivational, addictionType: type.rawValue),
                MemeItem(text: "'It's just a plant' — so is poison ivy, what's your point", category: .roast, addictionType: type.rawValue),
                MemeItem(text: "Week 2: Colors look brighter. Food tastes real. Feelings feel.", category: .relatable, addictionType: type.rawValue),
                MemeItem(text: "Your personality without weed is who you actually are. Meet them.", category: .distraction, addictionType: type.rawValue),
                MemeItem(text: "Every sober day is a day your brain heals", category: .consequence, addictionType: type.rawValue),
            ]
        case .gambling:
            return [
                MemeItem(text: "The house always wins. But today, YOU win by not playing.", category: .motivational, addictionType: type.rawValue),
                MemeItem(text: "POV: Your bank account has more than $0 at month end", category: .roast, addictionType: type.rawValue),
                MemeItem(text: "'Just one more bet' is the most expensive sentence in any language", category: .relatable, addictionType: type.rawValue),
                MemeItem(text: "The only guaranteed win is not gambling at all", category: .distraction, addictionType: type.rawValue),
                MemeItem(text: "Casinos don't have clocks or windows for a reason", category: .consequence, addictionType: type.rawValue),
                MemeItem(text: "Your savings account existing is the real jackpot", category: .motivational, addictionType: type.rawValue),
                MemeItem(text: "The rush of winning is never worth the crash of losing", category: .roast, addictionType: type.rawValue),
                MemeItem(text: "You're not 'due for a win'. That's not how probability works.", category: .relatable, addictionType: type.rawValue),
                MemeItem(text: "Every gambling app is designed by psychologists to keep you losing", category: .distraction, addictionType: type.rawValue),
                MemeItem(text: "The money you didn't lose today is the money you earned", category: .consequence, addictionType: type.rawValue),
                MemeItem(text: "Financial freedom > the thrill of a bet", category: .motivational, addictionType: type.rawValue),
                MemeItem(text: "Your credit score healing is the real high score", category: .roast, addictionType: type.rawValue),
                MemeItem(text: "Nobody brags about their losses. Because there are always more losses.", category: .relatable, addictionType: type.rawValue),
                MemeItem(text: "Delete the apps. Block the sites. Protect the bag.", category: .distraction, addictionType: type.rawValue),
                MemeItem(text: "Betting on yourself > betting on anything else", category: .consequence, addictionType: type.rawValue),
            ]
        case .overspending:
            return [
                MemeItem(text: "Savings account going up for the first time: 'Wait, what's happening?'", category: .motivational, addictionType: type.rawValue),
                MemeItem(text: "Your cart at 3AM: 'You don't need any of this'", category: .roast, addictionType: type.rawValue),
                MemeItem(text: "Retail therapy is just debt with extra steps", category: .relatable, addictionType: type.rawValue),
                MemeItem(text: "The dopamine from buying lasts 10 minutes. The bill lasts 30 days.", category: .distraction, addictionType: type.rawValue),
                MemeItem(text: "Future you is grateful present you closed that tab", category: .consequence, addictionType: type.rawValue),
                MemeItem(text: "Your unread emails from shopping sites can stay unread. Freedom.", category: .motivational, addictionType: type.rawValue),
                MemeItem(text: "'Add to cart' is the most dangerous button ever invented", category: .roast, addictionType: type.rawValue),
                MemeItem(text: "You don't need it. You want it. There's a difference.", category: .relatable, addictionType: type.rawValue),
                MemeItem(text: "The sale is designed to make you spend, not save", category: .distraction, addictionType: type.rawValue),
                MemeItem(text: "Check your bank account. That's your motivation.", category: .consequence, addictionType: type.rawValue),
                MemeItem(text: "Unsubscribe from every marketing email. Watch the urges disappear.", category: .motivational, addictionType: type.rawValue),
                MemeItem(text: "Owning less but better > owning more and worse", category: .roast, addictionType: type.rawValue),
                MemeItem(text: "The 24-hour rule: If you still want it tomorrow, reconsider. You won't.", category: .relatable, addictionType: type.rawValue),
                MemeItem(text: "Your closet full of stuff you never use is judging you", category: .distraction, addictionType: type.rawValue),
                MemeItem(text: "Financial peace > temporary shopping high", category: .consequence, addictionType: type.rawValue),
            ]
        case .caffeine:
            return [
                MemeItem(text: "Day 3 without caffeine: 'So THIS is what natural energy feels like'", category: .motivational, addictionType: type.rawValue),
                MemeItem(text: "Your adrenal glands healing: 'We can rest now'", category: .roast, addictionType: type.rawValue),
                MemeItem(text: "Sleeping without caffeine anxiety hits different", category: .relatable, addictionType: type.rawValue),
                MemeItem(text: "Water. Just drink water. It works.", category: .distraction, addictionType: type.rawValue),
                MemeItem(text: "Your blood pressure thanking you for switching to herbal tea", category: .consequence, addictionType: type.rawValue),
                MemeItem(text: "Needing coffee to function isn't a personality — it's a dependency", category: .motivational, addictionType: type.rawValue),
                MemeItem(text: "Your 3PM crash doesn't exist when you're not on caffeine", category: .roast, addictionType: type.rawValue),
                MemeItem(text: "Natural energy after caffeine withdrawal: built different", category: .relatable, addictionType: type.rawValue),
                MemeItem(text: "Your anxiety was never yours. It was the caffeine's.", category: .distraction, addictionType: type.rawValue),
                MemeItem(text: "Heart palpitations aren't normal. You just got used to them.", category: .consequence, addictionType: type.rawValue),
                MemeItem(text: "Week 2 without caffeine: 'Why does morning feel... calm?'", category: .motivational, addictionType: type.rawValue),
                MemeItem(text: "'I only have one cup a day' — size: bathtub", category: .roast, addictionType: type.rawValue),
                MemeItem(text: "Your teeth going from coffee stained to actually white", category: .relatable, addictionType: type.rawValue),
                MemeItem(text: "Headache at day 2 means your body was THAT dependent. Think about it.", category: .distraction, addictionType: type.rawValue),
                MemeItem(text: "Caffeine-free sleep is the best drug you'll ever try", category: .consequence, addictionType: type.rawValue),
            ]
        }
    }
}
