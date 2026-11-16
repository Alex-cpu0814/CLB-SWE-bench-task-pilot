Proposal: pygame.time.set_event_timer method accept Event class as parameter
Now pygame.time.set_timer(eventid, milliseconds, once) only accepts an integer as eventid parameter.
Other event methods can differentiate events with the same event id by additional parameters and I can define and push user defined events with self defined parameters. As of now this is not possible for timer events.
Since the number of user event ids is limited, applications with many different timer event types have to rely on other timer methods.

Proposal:

Implementation of a new method pygame.time.set_event_timer(event, milliseconds, once) 
where the event parameter is an event created by pygame.event.Event

I believe, that this would enhance the usability for applications with many different timer event types very much   

**Related Docs:** https://www.pygame.org/docs/ref/time.html#pygame.time.set_timer

 

pygame.time.set_timer() accept numevents argument
Currently, pygame.time.set_timer() has only two options, it can either keep sending events forever, or send once and stop.
IMHO, it would be more useful if we had a way to send a particular amount of events, that can be easily specified by the user.
I know a way to make this work, and I can implement it, if you all like the idea too.
And don’t worry, I won’t break back-compat ;)

PS: Event refactor PR is almost done, took me half an hour to write the description for the PR, so you can expect how long it must be
