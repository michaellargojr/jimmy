import Foundation

// Help me choose: the questions that tell the machines in the list apart, and each machine's
// answers. A first pass from what makes each kind its own (path, position, arms, pads). A question
// a machine leaves out matches any answer. Hack squat and V-squat still tie: sources disagree.

struct ChooseAnswer: Hashable, Identifiable {
    let id: String
    let text: String
}

struct ChooseQuestion: Hashable, Identifiable {
    let id: String
    let title: String
    let answers: [ChooseAnswer]
}

/// In the order they're asked when two split the machines equally well.
let CHOOSE_QUESTIONS: [ChooseQuestion] = [
    ChooseQuestion(id: "body", title: "What position are you in?", answers: [ChooseAnswer(id: "sitting", text: "Sitting"), ChooseAnswer(id: "standing", text: "Standing"), ChooseAnswer(id: "lying", text: "Lying down"), ChooseAnswer(id: "kneeling", text: "Kneeling"), ChooseAnswer(id: "bent", text: "Bent over at the hips"), ChooseAnswer(id: "legpress", text: "In a leg press")]),
    ChooseQuestion(id: "start", title: "Where do the handles start?", answers: [ChooseAnswer(id: "overhead", text: "Above your head"), ChooseAnswer(id: "high", text: "High in front of you"), ChooseAnswer(id: "chest", text: "In front of your chest"), ChooseAnswer(id: "low", text: "Down low")]),
    ChooseQuestion(id: "path", title: "Which way does it move?", answers: [ChooseAnswer(id: "down", text: "Straight down"), ChooseAnswer(id: "downback", text: "Down and back"), ChooseAnswer(id: "back", text: "Straight back"), ChooseAnswer(id: "out", text: "Straight out"), ChooseAnswer(id: "outin", text: "Out and toward each other"), ChooseAnswer(id: "up", text: "Straight up"), ChooseAnswer(id: "upin", text: "Up and toward each other"), ChooseAnswer(id: "angle", text: "Up at an angle"), ChooseAnswer(id: "arc", text: "In an arc")]),
    ChooseQuestion(id: "own", title: "Does each side move on its own?", answers: [ChooseAnswer(id: "yes", text: "Yes, each side moves alone"), ChooseAnswer(id: "no", text: "No, both move together")]),
    ChooseQuestion(id: "wide", title: "Do your hands start wide, past your shoulders?", answers: [ChooseAnswer(id: "yes", text: "Yes, wide"), ChooseAnswer(id: "no", text: "No, about shoulder width")]),
    ChooseQuestion(id: "contact", title: "What do you push with?", answers: [ChooseAnswer(id: "hands", text: "Handles in your hands"), ChooseAnswer(id: "forearms", text: "Pads on your forearms")]),
    ChooseQuestion(id: "elbows", title: "Where are your elbows?", answers: [ChooseAnswer(id: "front", text: "On a pad in front of you"), ChooseAnswer(id: "head", text: "Up by your head")]),
    ChooseQuestion(id: "hold", title: "What holds you in?", answers: [ChooseAnswer(id: "shoulders", text: "Pads on your shoulders"), ChooseAnswer(id: "belt", text: "A belt around your hips")]),
]

/// Asked last: it decides Plates or Stack, not which machine.
let LOADING_QUESTION = ChooseQuestion(id: "loading", title: "How do you add weight?", answers: [ChooseAnswer(id: "plates", text: "Plates on the side"), ChooseAnswer(id: "stack", text: "A pin in a weight stack")])

/// Base (lowercased) > machine name > question id > answer id.
private let MACHINE_TRAITS: [String: [String: [String: String]]] = [
    "chest press": [
        "Chest press": ["path": "out", "own": "no", "wide": "no"],
        "Iso-lateral chest press": ["path": "out", "own": "yes", "wide": "no"],
        "Converging chest press": ["path": "outin", "wide": "no"],
        "Wide chest press": ["path": "out", "own": "yes", "wide": "yes"],
    ],
    "incline press": [
        "Incline chest press": ["own": "no"],
        "Iso-lateral incline press": ["own": "yes"],
    ],
    "chest fly": [
        "Fly machine": ["contact": "hands"],
        "Pec deck": ["contact": "forearms"],
    ],
    "dip": [
        "Seated dip": ["body": "sitting"],
        "Assisted dip": ["body": "kneeling"],
    ],
    "pulldown": [
        "Lat pulldown": ["start": "overhead", "path": "down", "own": "no", "wide": "no"],
        "Iso-lateral pulldown": ["start": "overhead", "path": "down", "own": "yes", "wide": "no"],
        "High row": ["start": "high", "path": "downback", "own": "yes", "wide": "no"],
        "Wide pulldown": ["start": "overhead", "path": "down", "own": "yes", "wide": "yes"],
    ],
    "row": [
        "Seated row": ["body": "sitting", "start": "chest", "path": "back", "own": "no"],
        "Iso-lateral row": ["body": "sitting", "start": "chest", "path": "back", "own": "yes"],
        "T-bar row": ["body": "standing", "start": "low", "path": "up", "own": "no"],
        "Low row": ["body": "sitting", "start": "low", "path": "back", "own": "yes"],
    ],
    "shoulder press": [
        "Shoulder press": ["path": "up", "own": "no"],
        "Iso-lateral shoulder press": ["path": "up", "own": "yes"],
        "Converging shoulder press": ["path": "upin"],
    ],
    "lateral raise": [
        "Lateral raise machine": ["body": "sitting"],
        "Standing lateral raise machine": ["body": "standing"],
    ],
    "curl": [
        "Preacher curl machine": ["own": "no"],
        "Iso-lateral curl": ["own": "yes"],
    ],
    "tricep extension": [
        "Tricep extension machine": ["elbows": "front"],
        "Overhead tricep machine": ["elbows": "head"],
    ],
    "squat": [
        "Hack squat": ["hold": "shoulders", "path": "angle"],
        "Pendulum squat": ["hold": "shoulders", "path": "arc"],
        "Belt squat": ["hold": "belt", "path": "down"],
        "V-squat": ["hold": "shoulders", "path": "angle"],
    ],
    "leg press": [
        "45° leg press": ["path": "angle", "own": "no"],
        "Seated leg press": ["body": "sitting", "path": "out", "own": "no"],
        "Vertical leg press": ["body": "lying", "path": "up", "own": "no"],
        "Iso-lateral leg press": ["path": "angle", "own": "yes"],
    ],
    "leg extension": [
        "Leg extension": ["own": "no"],
        "Iso-lateral leg extension": ["own": "yes"],
    ],
    "leg curl": [
        "Seated leg curl": ["body": "sitting"],
        "Lying leg curl": ["body": "lying"],
        "Standing leg curl": ["body": "standing"],
        "Kneeling leg curl": ["body": "kneeling"],
    ],
    "calf raise": [
        "Standing calf raise": ["body": "standing"],
        "Seated calf raise": ["body": "sitting"],
        "Donkey calf raise": ["body": "bent"],
        "Leg press calf raise": ["body": "legpress"],
    ],
]

/// A machine's answers. Empty for a base or machine without any.
func machineTraits(base: String, machine: String) -> [String: String] {
    MACHINE_TRAITS[base.lowercased()]?[machine] ?? [:]
}
