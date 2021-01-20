from os import path

import pynvim
from astropy.io import fits

from typing import List, Union

Number = Union[int, float]


@pynvim.plugin
class FitsOpen:
    def __init__(self, nvim):
        self.nvim = nvim

    @pynvim.command("FITSHead", nargs=1, complete="file", bang=True, sync=True)
    def fits_preview_handler(self, args, bang):
        """
        Command that, given a FITS file, displays the headers in a new floating
        window.
        The only argument is the filename.
        A bang can be specified to remove the buffer (and therefore also the
        window) when it is left.
        """
        # Read file
        try:
            with fits.open(args[0]) as hdul:
                headers = hdul[0].header
        except OSError as e:
            if "Header missing END card." in e.args:
                self.nvim.api.err_writeln(
                    f"File '{args[0]}' is not a valid FITS file"
                )
            else:
                self.nvim.api.err_writeln(f"File '{args[0]}' is not a file")
            return

        # buf = self.nvim.current.buffer
        win = self.nvim.current.window

        # Prepare the buffer
        win_height = win.height
        win_width = win.width

        newbuf = self.nvim.api.create_buf(True, True)

        # Add headers to the buffer
        table = draw_fancy_table(list(headers.items()))
        w, h = len(table[0]), len(table)

        height = min(win_height - 4, h + 1)
        newbuf.append(table)
        config = {
            "relative": "win",
            "win": win.number,
            "width": w,
            "height": height,
            "col": win_width - w - 4,
            "row": 2,
            "style": "minimal",
        }

        # Actually spawn the window
        self.nvim.api.open_win(newbuf, True, config)

        # Print filename at top line
        self.nvim.current.line = path.split(args[0])[-1].center(w, " ")

        if not bang:
            # Close window on buffer leave
            autocommand = "autocmd BufLeave <buffer={0}> :bunload {0}"
            self.nvim.command(autocommand.format(newbuf.number))
            self.nvim.out_write("Leaving buffer will close the window\n")


def pad(string: str, n: int = 1, padstr: str = " "):
    """
    Pad the given string with n times the padstr on each side.
    """
    return padstr * n + string + padstr * n


def transpose(data: List[List[Union[Number, str]]]):
    """
    Transpose a 2 dimensional array. Requires a constant row & column length,
    although the rows and columns can have different lengths w.r.t. each other.

    Essentially:
        data[i, j] = data[j, i] for each i, j
    """
    return [[row[col] for row in data] for col in range(len(data[0]))]


def replace(string: str, indices: List[int], chars: Union[str, List[str]]):
    """
    Replaces the character at each index i (for each i in indices)
    with chars[i]

    Requires the indices to be sorted, but negative numbers are allowed (as
    long as they are not smaller than -N...). The negative numbers should be
    put at the end of the list.
    """
    N = len(string)
    # make sure negative numbers are made positive (by adding len(string))
    indices = [i + N if i < 0 else i for i in indices]
    newstr = ""
    prev = 0
    for idx, ch in zip(indices, chars):
        newstr += string[prev:idx] + ch
        prev = idx + 1
    return newstr + string[prev:]


#####################
# Utility functions #
#####################

# lines:
VERTICAL = 0
HORIZONTAL = 1
# corners:
NW = 0
NE = 1
SE = 2
SW = 3
# crossings:
MIDDLE = 0
LEFT = 1
RIGHT = 2
UP = 3
DOWN = 4


def draw_fancy_table(
    data: List[List[Union[Number, str]]],
    rows: bool = True,
    lines: str = "│─",
    corners: str = "┌┐┘└",
    crossings: str = "┼├┤┬┴",
    align: str = "<",
) -> List[str]:
    """
    TODO (2021-01-18): Add documentation
    """
    if len(data) < 1:
        raise ValueError("Data should now be empty")
    if rows:  # transpose to columns
        data = transpose(data)
    if len(align) == 1:
        align *= len(data)

    # Calculate maximal size per column. There are some tricks to handle
    # both number and string input
    max_elems = [max(col, key=lambda c: len(str(c))) for col in data]
    widths = [len(str(w)) for w in max_elems]

    # Make the format string (specify width & alignment)
    vline = lines[VERTICAL]
    row_fmt = pad(vline).join(
        ["{:" + al + str(width) + "}" for al, width in zip(align, widths)]
    )
    row_fmt = vline + " " + row_fmt + " " + vline

    # Prepare bottom and top row as a flat line
    top_row = lines[HORIZONTAL] * (sum(widths) + 3 * (len(widths) - 1) + 2 * 2)
    bot_row = top_row[:]  # copy

    # Find crossings
    cross_idxs = []
    previous = 1
    for width in widths[:-1]:
        cross_idxs.append(previous + width + 2)
    idxs = [0] + cross_idxs + [-1]

    # Replace corners and crossings
    top_row = replace(
        top_row,
        idxs,
        [corners[NW]] + len(cross_idxs) * [crossings[UP]] + [corners[NE]],
    )
    bot_row = replace(
        bot_row,
        idxs,
        [corners[SW]] + len(cross_idxs) * [crossings[DOWN]] + [corners[SE]],
    )

    # Format each row according to the format
    data = transpose(data)
    rowstrs = [row_fmt.format(*row) for row in data]

    # Compose everything
    table = [top_row] + rowstrs + [bot_row]

    return table
