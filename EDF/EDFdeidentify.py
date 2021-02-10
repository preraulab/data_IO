import os
import shutil
from tkinter import *
from tkinter import filedialog
from tkinter import messagebox

# Load the file(s)
root = Tk()
root.geometry('400x100')
root.title('EDF Deidentifier')

# Put some text on the blank window
canvas = Canvas(root, width=400, height=100, bg="white")
canvas.pack()
canvas.create_text(200, 50, text="EDF Deidentifier", font="Times 30 bold",)

root.withdraw()

# Load the file
root.filenames = filedialog.askopenfilenames(initialdir="~/", title="Select EDF file(s)",
                                             filetypes=(("EDF files", "*.edf"), ("All files", "*.*")))
# Handle file cancel
print(root.filenames)
if root.filenames == '':
    print('Goodbye file cancel')
    exit()

# Check if user wants to overwrite data
copy_file = messagebox.askyesnocancel(title="EDF Deidentifier", message="Would you like to save the a copy of data?")
print(copy_file)

# Exit if cancel
if copy_file is None:
    print('Goodbye')
    exit()

# Double check!
if not copy_file:
    result = messagebox.askyesno(title="EDF Deidentifier", message="Are you sure you want to overwrite all files?")
    if not result:
        print('Goodbye!')
        exit()

# Print filenames
print(root.filenames)

# Loop through all file names
for path in root.filenames:
    print(path)  # Print current path

    # Skip if bad file
    if not (os.path.isfile(path)):
        print("Invalid file: " + path)
        continue

    # Copy file to new name
    if copy_file:
        file_savedir = filedialog.askdirectory()
        path_new = file_savedir + '/' + os.path.basename(path)[0:-4] + '_deidentified.edf'
        print(path_new)
        shutil.copy(path, path_new)
        path = path_new

    # Open file(s) and deidentify
    f = open(path, "r+", encoding="iso-8859-1")  # 'r' = read
    try:
        f.write('%-8s' % "0")
        f.write('%-80s' % "DEIDENTIFIED")  # Remove patient info
        f.write('%-80s' % "DEIDENTIFIED")  # Remove recording info
        f.write('01.01.01')  # Set date as 01.01.01
    except UnicodeDecodeError:
        f.close()
        f = open(path, "r+", encoding="iso-8859-2")  # 'r' = read
        try:
            f.write('%-8s' % "0")
            f.write('%-80s' % "DEIDENTIFIED")  # Remove patient info
            f.write('%-80s' % "DEIDENTIFIED")  # Remove recording info
            f.write('01.01.01')  # Set date as 01.01.01
        except UnicodeDecodeError:
            f.close()
            f = open(path, "r+", encoding="utf-8")  # 'r' = read
            try:
                f.write('%-8s' % "0")
                f.write('%-80s' % "DEIDENTIFIED")  # Remove patient info
                f.write('%-80s' % "DEIDENTIFIED")  # Remove recording info
                f.write('01.01.01')  # Set date as 01.01.01
                f.close()
            finally:
                print('No valid encoding format found')
