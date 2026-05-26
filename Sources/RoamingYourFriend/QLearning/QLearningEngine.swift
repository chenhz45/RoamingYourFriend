import Foundation

/// Pure Q-learning algorithm for the character's roaming decisions.
final class QLearningEngine: @unchecked Sendable {

    enum Action: Int, CaseIterable {
        case up = 0, down, left, right, stay
    }

    let alpha: Double
    let gamma: Double
    let minEpsilon: Double
    let epsilonDecay: Double

    private var epsilon: Double
    private var qTable: [String: [Double]] = [:]
    private let queue = DispatchQueue(label: "com.roamingyourfriend.qlearning")

    init(alpha: Double = 0.1, gamma: Double = 0.9,
         epsilon: Double = 0.3, minEpsilon: Double = 0.05, epsilonDecay: Double = 0.995) {
        self.alpha = alpha
        self.gamma = gamma
        self.minEpsilon = minEpsilon
        self.epsilonDecay = epsilonDecay
        self.epsilon = epsilon
    }

    var currentEpsilon: Double {
        queue.sync { epsilon }
    }

    /// Temporarily boost exploration when the character gets stuck.
    func boostExploration() {
        queue.sync {
            epsilon = max(epsilon, 0.35)
        }
    }

    // MARK: - Action selection (ε-greedy with decay)

    func selectAction(for state: String) -> Action {
        queue.sync {
            let qValues = qTable[state] ?? Array(repeating: 0.0, count: Action.allCases.count)

            let action: Action
            if Double.random(in: 0..<1) < epsilon {
                action = Action.allCases.randomElement()!
            } else {
                let maxQ = qValues.max() ?? 0
                let bestActions = Action.allCases.enumerated().filter { qValues[$0.offset] == maxQ }.map(\.element)
                action = bestActions.randomElement()!
            }

            // Decay epsilon toward min
            epsilon = max(minEpsilon, epsilon * epsilonDecay)
            return action
        }
    }

    // MARK: - Q-value update

    func update(state: String, action: Action, reward: Double, nextState: String) {
        queue.async { [weak self] in
            guard let self else { return }
            var qValues = self.qTable[state] ?? Array(repeating: 0.0, count: Action.allCases.count)
            let nextMax = self.qTable[nextState]?.max() ?? 0.0
            let oldQ = qValues[action.rawValue]
            qValues[action.rawValue] = oldQ + self.alpha * (reward + self.gamma * nextMax - oldQ)
            self.qTable[state] = qValues
        }
    }
}
