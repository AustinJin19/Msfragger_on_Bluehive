# Msfragger_on_Bluehive
This shell script is designed for using msfragger on the cluster.
### Before running this shell script, remember to modify the path to raw data, MSfragger parameter document
### 1. Command line to run this shell script: 
``` $ sbatch --array=0-10%1 xxxx.sh ```
For SLURM JOB SYSTEM, --array=0-10%1 means run files 0, 1, 2, ..., 10 and one job each time. Python scripts crash when running multiple jobs.
