# Validated-Ledger-Project
This script is created as part of ripple technical coding round for my interview.

Description
The shell script periodically calls ripple server info command and record the sequence number of the latest validated ledger along with the current time. This data is then recorded in a file and then used to construct a plot time on X axis, and sequence number on y axis and age (time taken by server to validate ledger) of the each iteration on x2 axis that visualizes how frequently the ledger sequences incremented over time.

Installation Steps:

git clone https://github.com/deepakkukreja1985/Validated-Ledger-Project.git

Requirements

•	Ubuntu 16.04

•	BASH Shell

•	CURL version 7.47.0

•	JQ version 1.5.1

•	Gnuplot 5.0

•	Bats 0.4.0 (Bash Automated Test System)

How to Execute:

cd Validated-Ledger-Project/

./scripts/validated_ledger.sh

How to Execute BATS Test Suite:

cd scripts/

./install-bats-libs.sh

above step will download required libs in test folder

cd ../

mkdir test/tmp

./test/preexecution.bats     

./test/postexecution.bats


Documentation

You can find detail documentation in “/doc” folder

https://github.com/deepakkukreja1985/Validated-Ledger-Project/tree/master/doc
