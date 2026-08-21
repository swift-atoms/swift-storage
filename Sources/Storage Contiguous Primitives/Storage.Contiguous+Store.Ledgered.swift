public import Memory_Region_Primitives
public import Store_Ledgered_Primitives

extension Storage.Contiguous: Store.Ledgered.`Protocol`
where Allocation: Memory.Region & ~Copyable, Element: ~Copyable {}
