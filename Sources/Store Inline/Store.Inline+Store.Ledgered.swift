public import Store_Ledgered

extension Store.Inline: Store.Ledgered.`Protocol` where Element: ~Copyable {}
