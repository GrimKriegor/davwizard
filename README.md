# davwizard

A curses wizard to ease the configuration of a terminal based calendar, tasks and contact stack.


## Software

- [vdirsyncer](https://github.com/pimutils/vdirsyncer) - Synchronization and offline mirroring
- [khal](https://github.com/pimutils/khal) - Calendar client
- [todoman](https://github.com/pimutils/todoman) - Task manager
- [khard](https://github.com/scheibler/khard/) - Address book client
- [cron](https://github.com/cronie-crond/cronie/) - Scheduled synchronization
- [gnupg](https://gnupg.org/) - Encrypt secrets


## Data

- `~/.config/davwizard/accounts` - Account configuration and secrets
- `~/.vdirsyncer` - Synchronization metadata
- `~/.calendars` - Calendar and task ics files
- `~/.contacts` - Address book vcs files


## Download

```
git clone https://github.com/GrimKriegor/davwizard.git ~/.config/davwizard
```


## Run

Either symlink `davwizard.sh` into your `$PATH` or run it directly:

```
~/.config/davwizard/davwizard.sh
```


## Attribution

Heavily inspired in Luke Smith's [mutt-wizard](https://github.com/LukeSmithxyz/mutt-wizard).

This tool intends to do the same thing for `khal`, `todoman`, `khard` and `vdirsyncer`.

