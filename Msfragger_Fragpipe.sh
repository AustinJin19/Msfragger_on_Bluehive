#!/bin/bash

#####     File Name: non-ion mobility data running


#########
#Set options
################################################
#Set resource requirements
#SBATCH --time=2-00:00:00 --partition=preempt --output=tmp%j.log --job-name=macrodomain_ribo --cpus-per-task=24 --mem=200G

module load mono/5.18.0
module load jdk/11.0.10
module load anaconda3/5.3.0
#conda init bash
conda activate mass_spec
set -xe

# Specify paths of tools and files to be analyzed.
dataDirPath="/scratch/yliang44/MS_Data/OCT_29_Yuan_DDA/" #.raw files
python="/home/yliang44/MASS_SPEC/fragpipe/tools" #python file to split database
fastaPath="/home/yliang44/MASS_SPEC/fragpipe/Database/2024_10_15_decoys_reviewed_isoforms_contam_UP000000589.fas" # reference protein database
msfraggerPath="/home/yliang44/MASS_SPEC/MSFragger-4.1/MSFragger-4.1.jar" # download from http://msfragger-upgrader.nesvilab.org/upgrader/
fraggerParamsPath="/home/yliang44/MASS_SPEC/MSFragger-4.1/parameters/YL_RibosePhosphate_ADPr_fragger.params" # Parameter for MSfragger from fragpipe
philosopherPath="/home/yliang44/MASS_SPEC/philosopher" # download from https://github.com/Nesvilab/philosopher/releases/latest
#crystalcPath="CrystalC.jar" # download from https://github.com/Nesvilab/Crystal-C/releases/latest
#crystalcParameterPath="crystalc.params"
ionquantPath="/home/yliang44/MASS_SPEC/IonQuant-1.10.27/IonQuant-1.10.27.jar" # download from https://github.com/Nesvilab/IonQuant/releases/latest
decoyPrefix="rev_"
cd $dataDirPath

rawfiles=(*.raw) # get all raw files in the data directory
echo "rawsfiles: ${rawfiles[*]}"
rawfile=${rawfiles[$SLURM_ARRAY_TASK_ID]} # each time choose one .raw file to process using array_task_id.
echo "RUNNING File: ${rawfile}"
# Run MSFragger. Change the -Xmx value according to your computer's memory.
#java -Xmx160G -jar $msfraggerPath $fraggerParamsPath $dataDirPath/$rawfile    #/<spectral files ending with .mzML or .raw> uncomment this one while the file size is small

python3 $python/msfragger_pep_split.py 4 "java -Xmx160G -jar" $msfraggerPath $fraggerParamsPath $dataDirPath/$rawfile # Use this one when more than 2 billion peptides were searched in the first search
# Move pepXML files to current directory.

mkdir $rawfile

mv $dataDirPath/*.pepXML ./$rawfile/

# Move MSFragger tsv files to current directory.
#mv $dataDirPath/*.tsv ./$rawfile/  # Comment this line if localize_delta_mass = 0 in your fragger.params file.
cd ./$rawfile
# For open searches, run Crystal-C. Otherwise, don't run Crystal-C (comment this for-loop).
#for myFile in ./*.pepXML
#do
#       java -Xmx64G -cp $crystalcPath Main $crystalcParameterPath $myFile
#done

# Run PeptideProphet, ProteinProphet, and FDR filtering with Philosopher
$philosopherPath workspace --clean
$philosopherPath workspace --init
$philosopherPath database --annotate $fastaPath --prefix $decoyPrefix
# Pick one from the following three commands and comment the other two.
$philosopherPath peptideprophet --nonparam --expectscore --decoyprobs --ppm --accmass --decoy $decoyPrefix --database $fastaPath ./*.pepXML # Closed search
#$philosopherPath peptideprophet --nonparam --expectscore --decoyprobs --masswidth 1000.0 --clevel -2 --decoy $decoyPrefix --combine --database $fastaPath ./*_c.pepXML # Open search if you ran Crystal-C
#$philosopherPath peptideprophet --nonparam --expectscore --decoyprobs --masswidth 1000.0 --clevel -2 --decoy $decoyPrefix --combine --database $fastaPath ./*.pepXML # Open search if you did NOT ran Crystal-C
#$philosopherPath peptideprophet --nonparam --expectscore --decoyprobs --ppm --accmass --nontt --decoy $decoyPrefix --database $fastaPath ./*.pepXML # Non-specific closed search

$philosopherPath proteinprophet --maxppmdiff 2000000 --output combined ./*.pep.xml

# Pick one from the following two commands and comment the other one.
$philosopherPath filter --sequential --razor --mapmods --tag $decoyPrefix --pepxml ./ --protxml ./combined.prot.xml # closed or non-specific closed search
#$philosopherPath filter --sequential --razor --mapmods --tag $decoyPrefix --pepxml ./interact.pep.xml --protxml ./combined.prot.xml # Open search

# Make reports.
$philosopherPath report
$philosopherPath workspace --clean

# Perform quantification.

#java -Xmx64G -jar $ionquantPath <options> <path to .pepXML>
