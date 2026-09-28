#if Generational
public import Buffer
import Cardinal
import Index
import Ordinal
import Tagged

extension Storage.Generational: Buffer.`Protocol` where Allocation: ~Copyable, Element: ~Copyable {}
#endif
