import Foundation
import XCTest
@testable import DSHProtocol

final class PhoneFontPreferencesTests: XCTestCase {
    private let roles: [(ThemeFontRole, String)] = [
        (.text, "dsh.fontSize"),
        (.code, "dsh.codeFontSize"),
        (.terminal, "dsh.terminalFontSize"),
    ]

    func testUnconfiguredInstallUsesLargerDefaultsWithoutPersistingThem() {
        withDefaults { defaults, _ in
            for (role, key) in roles {
                let expected = PhoneFontPreferences.defaultSize(role)
                XCTAssertNil(defaults.object(forKey: key))
                XCTAssertEqual(PhoneFontPreferences.size(role, defaults: defaults), expected)
                XCTAssertNil(defaults.object(forKey: key), "Reading a default must not pin it for future upgrades")
            }
        }
    }

    func testUpgradePreservesEveryStoredValueIncludingOldDesktopDefaults() {
        withDefaults { defaults, _ in
            for (role, key) in roles {
                let spec = themeFontSizeSpec(role)
                for value in spec.range {
                    defaults.set(value, forKey: key)
                    XCTAssertEqual(PhoneFontPreferences.size(role, defaults: defaults), value)
                    XCTAssertEqual(defaults.integer(forKey: key), value)
                }
                defaults.set(spec.default, forKey: key)
                XCTAssertEqual(PhoneFontPreferences.size(role, defaults: defaults), spec.default)
            }
        }
    }

    func testExplicitChoiceAtNewDefaultPersistsAcrossPreferenceInstances() {
        withDefaults { defaults, suite in
            for (role, key) in roles {
                let value = PhoneFontPreferences.defaultSize(role)
                PhoneFontPreferences.setSize(value, for: role, defaults: defaults)
                XCTAssertEqual(defaults.object(forKey: key) as? Int, value)
            }
            let reopened = UserDefaults(suiteName: suite)!
            for (role, _) in roles {
                let value = PhoneFontPreferences.defaultSize(role)
                XCTAssertEqual(PhoneFontPreferences.size(role, defaults: reopened), value)
            }
        }
    }

    func testEachRoleCanStepBothWaysAndClampsAtExistingBounds() {
        withDefaults { defaults, _ in
            for (role, key) in roles {
                let initial = PhoneFontPreferences.defaultSize(role)
                XCTAssertTrue(themeFontSizeCanIncrease(role, value: initial))
                XCTAssertTrue(themeFontSizeCanDecrease(role, value: initial))
                for delta in [-1, 1] {
                    let next = themeFontSizeStepped(role, value: initial, delta: delta)
                    PhoneFontPreferences.setSize(next, for: role, defaults: defaults)
                    XCTAssertEqual(PhoneFontPreferences.size(role, defaults: defaults), initial + delta)
                }
                let range = themeFontSizeSpec(role).range
                PhoneFontPreferences.setSize(-100, for: role, defaults: defaults)
                XCTAssertEqual(defaults.integer(forKey: key), range.lowerBound)
                PhoneFontPreferences.setSize(100, for: role, defaults: defaults)
                XCTAssertEqual(defaults.integer(forKey: key), range.upperBound)
                defaults.set(-100, forKey: key)
                XCTAssertEqual(PhoneFontPreferences.size(role, defaults: defaults), range.lowerBound)
                defaults.set(100, forKey: key)
                XCTAssertEqual(PhoneFontPreferences.size(role, defaults: defaults), range.upperBound)
            }
        }
    }

    func testChangingOneRoleDoesNotMaterializeOtherDefaultsOrHostPreferences() {
        withDefaults { defaults, suite in
            PhoneFontPreferences.setSize(18, for: .text, defaults: defaults)
            XCTAssertEqual(defaults.persistentDomain(forName: suite)?.count, 1)
            XCTAssertEqual(defaults.integer(forKey: "dsh.fontSize"), 18)
            XCTAssertNil(defaults.object(forKey: "dsh.codeFontSize"))
            XCTAssertNil(defaults.object(forKey: "dsh.terminalFontSize"))
            defaults.removeObject(forKey: "dsh.fontSize")
            XCTAssertEqual(PhoneFontPreferences.size(.text, defaults: defaults), PhoneFontPreferences.defaultSize(.text))
            XCTAssertNil(defaults.object(forKey: "dsh.fontSize"))
        }
    }

    func testUnconfiguredUpgradeUsesCurrentDefaultWhileExplicitOldPhoneChoiceSurvives() {
        withDefaults { defaults, suite in
            for (role, key) in roles {
                let oldPhoneSize = role == .text ? 16 : role == .code ? 13 : 14
                XCTAssertGreaterThan(PhoneFontPreferences.size(role, defaults: defaults), oldPhoneSize)
                PhoneFontPreferences.setSize(oldPhoneSize, for: role, defaults: defaults)
                let reopened = UserDefaults(suiteName: suite)!
                XCTAssertEqual(PhoneFontPreferences.size(role, defaults: reopened), oldPhoneSize)
                defaults.removeObject(forKey: key)
                XCTAssertEqual(PhoneFontPreferences.size(role, defaults: defaults), PhoneFontPreferences.defaultSize(role))
            }
        }
    }

    func testReadingOrReapplyingAContentSizeNeverAddsTheInterfaceEnlargement() {
        withDefaults { defaults, _ in
            for (role, _) in roles {
                for chosen in themeFontSizeSpec(role).range {
                    PhoneFontPreferences.setSize(chosen, for: role, defaults: defaults)
                    for _ in 0..<3 {
                        let rendered = PhoneFontPreferences.size(role, defaults: defaults)
                        XCTAssertEqual(rendered, chosen)
                        PhoneFontPreferences.setSize(rendered, for: role, defaults: defaults)
                    }
                }
            }
        }
    }

    func testMalformedStoredSizeUsesDefaultWithoutOverwritingThePreference() {
        withDefaults { defaults, _ in
            for (role, key) in roles {
                defaults.set("not-a-size", forKey: key)
                XCTAssertEqual(PhoneFontPreferences.size(role, defaults: defaults), PhoneFontPreferences.defaultSize(role))
                XCTAssertEqual(defaults.string(forKey: key), "not-a-size")
                PhoneFontPreferences.setSize(themeFontSizeSpec(role).min, for: role, defaults: defaults)
                XCTAssertEqual(PhoneFontPreferences.size(role, defaults: defaults), themeFontSizeSpec(role).min)
            }
        }
    }

    private func withDefaults(_ body: (UserDefaults, String) -> Void) {
        let suite = "PhoneFontPreferencesTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        body(defaults, suite)
    }
}
