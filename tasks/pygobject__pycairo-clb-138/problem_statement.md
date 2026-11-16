Add RasterSourcePattern
We can track the lifetime of the callbacks set there through set_user_data.
We can ignore the callback data imo. It's not per callback which rules out passing *args through  and python closures should work fine.
