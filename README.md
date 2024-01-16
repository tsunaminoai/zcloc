# zcloc

An exercise in code-kitting to replace [cloc.pl](https://github.com/hrbrmstr/cloc) with zig.

## Installation

Using zig master.

```bash
  zig build -Doptimize=ReleaseFast run -- .
```

## Usage

> -h, --help
> Display this help and exit.

> -x, --exclude PATH
> Exclude directories from search

## Timing

```sh
~/c/z/zcloc main• ❱ time zig-out/bin/zcloc .                                                                               (base)
Getting list of files
Files to consider: 9
Ignored files: 141
Language        Files           Blank           Comment         Code

Perl            1               701             1351            12403
zig             6               42              67              315
Python          1               133             74              472

Sum             8               876             1492            13190

________________________________________________________
Executed in  286.92 millis    fish           external
   usr time   65.06 millis   51.00 micros   65.01 millis
   sys time  250.62 millis  707.00 micros  249.91 millis

```

For reference:

```sh
❱ time cloc .
      76 text files.
      36 unique files.
     159 files ignored.

github.com/AlDanial/cloc v 1.98  T=1.15 s (31.2 files/s, 31616.3 lines/s)
-------------------------------------------------------------------------------
Language                     files          blank        comment           code
-------------------------------------------------------------------------------
JavaScript                      15            990           1027          15654
Perl                             1            701           1357          12397
HTML                             6            129              0           2396
Text                             7              0              0            515
Zig                              6             67             58            486
Python                           1            133            272            274
-------------------------------------------------------------------------------
SUM:                            36           2020           2714          31722
-------------------------------------------------------------------------------

________________________________________________________
Executed in    1.57 secs    fish           external
   usr time    1.15 secs   66.00 micros    1.15 secs
   sys time    0.12 secs  871.00 micros    0.12 secs
```
