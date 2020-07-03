import Foundation

extension UserDefaults {
    public struct KeyValueObservedChange<Value> {
        public typealias Kind = NSKeyValueChange

        public let kind: KeyValueObservedChange<Value>.Kind

        ///newValue and oldValue will only be non-nil if .new/.old is passed to `observe()`.
        ///In general, get the most up to date value by accessing it directly on the observed object instead.
        public let newValue: Value?

        public let oldValue: Value?

        ///indexes will be nil unless the observed KeyPath refers to an ordered to-many property
        public let indexes: IndexSet?

        ///'isPrior' will be true if this change observation is being sent before the change happens,
        ///due to .prior being passed to `observe()`
        public let isPrior: Bool
    }

    public class KeyValueObservation<Value>: NSObject {
        private unowned let userDefaults: UserDefaults
        private let key: Key<Value>
        private var changeHandler: (UserDefaults, KeyValueObservedChange<Value>) -> Void

        init(
            userDefaults: UserDefaults = .standard,
            key: Key<Value>, options: NSKeyValueObservingOptions,
            changeHandler: @escaping (UserDefaults, KeyValueObservedChange<Value>) -> Void
        ) {
            self.userDefaults = userDefaults
            self.changeHandler = changeHandler
            self.key = key
            super.init()
            userDefaults.addObserver(self, forKeyPath: key.rawValue, options: options, context: nil)
        }

        public override func observeValue(
            forKeyPath keyPath: String?,
            of object: Any?,
            change: [NSKeyValueChangeKey: Any]?,
            context: UnsafeMutableRawPointer?
        ) {
            guard let change = change, object != nil, keyPath == key.rawValue else { return }
            changeHandler(
                userDefaults,
                KeyValueObservedChange(
                    kind: NSKeyValueChange(rawValue: change[.kindKey] as! UInt)!,
                    newValue: change[.newKey] as? Value,
                    oldValue: change[.oldKey] as? Value,
                    indexes: change[.indexesKey] as? IndexSet,
                    isPrior: change[.notificationIsPriorKey] as? Bool == true
                )
            )
        }

        deinit {
            userDefaults.removeObserver(self, forKeyPath: key.rawValue, context: nil)
        }
    }

    public func observe<Value>(
        _ key: Key<Value>,
        options: NSKeyValueObservingOptions = [.new],
        changeHandler: @escaping (UserDefaults, KeyValueObservedChange<Value>) -> Void
    ) -> UserDefaults.KeyValueObservation<Value> {
        KeyValueObservation<Value>(userDefaults: self, key: key, options: options, changeHandler: changeHandler)
    }
}

extension UserDefaultsBindable {
    public func observe(
        options: NSKeyValueObservingOptions = [.new],
        _ changeHandler: @escaping (Self, UserDefaults.KeyValueObservedChange<ValueType>) -> Void
    ) -> UserDefaults.KeyValueObservation<ValueType> {
        userDefaults.observe(self.key, options: options) {
            changeHandler(self, $1)
        }
    }
}
