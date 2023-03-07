import sys

if len(sys.argv) < 2:
	filename = input("file: ")
else:
	filename = sys.argv[1]
if len(sys.argv) < 3:
	limit = 100000000
else:
	limit = int(sys.argv[2])
outfilename = filename + "_sorted" if '.' not in filename else filename[:filename.rfind('.')] + "_sorted" + filename[filename.rfind('.'):]

with open(filename, "r") as f:
	ln = f.readlines()
with open(outfilename, "w") as f:
	f.write(ln[0] + ln[1] + ln[2])
	stats = ln[-1]
	ln = ln[3:-1]
	scored_ln = [(-float(l[l.rfind(':')+1:].strip()), l) for l in ln]
	sorted_ln = sorted(scored_ln)
	if len(sorted_ln) > limit:
		sorted_ln = sorted_ln[:limit]
	sorted_ln = [l[1] for l in sorted_ln]
	f.write("".join(sorted_ln))
	f.write(stats)
