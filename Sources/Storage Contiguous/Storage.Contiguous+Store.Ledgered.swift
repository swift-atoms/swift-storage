public import Memory_Region
public import Store_Ledgered

extension Storage.Contiguous: Store.Ledgered.`Protocol`
where Allocation: Memory.Region & ~Copyable, Element: ~Copyable {}
