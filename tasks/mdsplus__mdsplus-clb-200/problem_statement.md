UIDs are now 32 bits so can no longer fit uid and gid
On linux UIDs are now 32 bit integers.  The 32bits in the NCI are no longer wide enough to hold both a UID and a GID.

I propose dropping the GID and just storing the UID.  This will involve changing dir/full to display the UID and username and not try to do the group.

The current code which sets the owner_id to:
```
((gid_t)getgid() << 16) | (uid_t)getuid()
```
works fine if neither has any of their high 16 bits set.  Otherwise it breaks.

I will make this change unless someone objects. 

We could say if the uid does not have any high bit sets then put the low 16 bits of the gid in the 16 bits of the owner id, but then I do not thing we will be able to distinguish the two cases when we read them back.

