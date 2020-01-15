# Nextflow introduction

## To clone this repo and install Nextflow
Github repository: [https://github.com/cellgeni/nf-introduction](https://github.com/cellgeni/nf-introduction)
```
git clone https://github.com/cellgeni/nf-introduction.git
cd nf-introduction/scripts
curl -s https://get.nextflow.io | bash
# use wget if curl is not available
# wget -qO- https://get.nextflow.io | bash
ls
```

Stijn van Dongen (svd) - Cellular Genetics (Informatics) - Wellcome Sanger Institute

#  Nextflow
##  Data-driven computational pipelines


Long ago we had shell scripts.  
And Makefiles.  
. . . :sweat_smile: many many hacky solutions around shell scripts and Makefiles  

Now we have Nextflow, Snakemake, Cromwell, Galaxy .... :yum:



###  A nextflow pipeline can

*   **combine multiple programs** sequentially and in parallel
*   run on **different executors**: e.g. local computer, LSF, k8s, AWS, slurm ...
*   use **containers** (Docker, singularity)
*   manages input/output **dependencies, concurrency, resources** (cpus, memory)
*   **retry** failed tasks
*   **resume** interrupted workflows; data is cached
*   and more


###  Nextflow removes all the hassle of organising files in directories

*   It does it for you.
*   Files become more like variables and arrays
*   These are passed between processes/tasks
*   Units of computation are tasks, each task has its own task directory
*   A parallelised process will have multiple tasks
*   Nextflow takes care of linking files between task directories
*   Task directories show you how NF works, allow inspection / debugging


### We send/get files (and values) to/from channels
*   Channel operations allow us to organise the data flow
*   No need to handle files after making them, they appear by (channel) magic
*   Using nextflow operators such as `mix`, `flatten`, `filter`, `map`, `collect` et cetera
*   Nextflow translates these operations to file-system task directory organisation


## Configuration and executor

This is well documented (see end of this presentation), and can be copied/modified
from existing pipelines. In the simplest case, local executor, use this:


```
executor {
    name   = 'local'
    cpus   = 16
    memory = '48GB'
}

withName: myniceprocess1 {
  cpus = 2
  memory = 30.GB
}
withName: myniceprocess2 {
  cpus = 4                           // Needs hook; see below
  memory = 20.GB
}

```

e.g. in a file `local.config` and add `-c local.config` to the nextflow command line.
This is useful for example on an Openstack instance. If the instance has N GB, specify
N-4 GB in the config (leave 4 for nextflow itself), and leave one or two CPUs for Nextflow.

With the above, Nextflow will calculate how many jobs it can run concurrently using all CPUs
and memory (but not more).

Use the Nextflow option `-with-report` to get a very pretty report on time, disk, and memory usage.

Finally, configuration is powerful, and allows e.g.

```
  withName: star {
    errorStrategy = { task.exitStatus == 130 ? 'retry' : 'ignore' }
    cpus = {  8 * Math.min(2, task.attempt) }
                          // Note below grows to about 100GB on 2 retries.
    memory = {  40.GB * task.attempt * 1.6 ** (task.attempt - 1) }
  }
```

## Code examples


The examples in this introduction are very abstract; files with
small/nonsensical content, no bioinformatics programs. To understand Nextflow
you don't need those, and it helps to keep things small. It's the quickest way
to test: Just mimic the structure (presence and relationship) of files going in
and out, what's in them does not matter.

Nextflow is a unix tool: you put files in, and you get more files.

This introduction focuses heavily on channels and files. Towards the very end
it may be a tiny bit overwhelming; but the reward is a fully functional non-trivial
little pipeline with manifest file, input reading, and scatter/gather parallelisation.


### [A single process](scripts/1_a_process.nf)

```
params.str    = 'the quick brown dog jumps over a lazy dog'
params.outdir = 'results'

process splitLetters {

    publishDir "${params.outdir}/1", mode: 'link'

    output:
    file 'chunk_*'

    shell:
    '''
    printf '!{params.str}' | split -b 10 - chunk_
    '''
}

// Things to notice:
// - params (user options) are implicitly overridden on command line.
// - params command line: double dash, e.g. --str 'pack my box with five dozen liquor jugs' sets params.str
// - Nextflow command line options: single dash, e.g. -ansi-log false -with-trace -w <workdirectory>.
// - String variable interpolation in publishDir.
// - Alternative variable interpolation in shell section - useful as it's shell code.
// - Tag is useful in more realistic cases, accepts variable interpolation as well
```

Example invocations:
```
./nextflow run 1_a_process.nf
./nextflow run 1_a_process.nf --str 'pack my box with five dozen liquor jugs'
```

###  On-disk organisation by Nextflow

```
node-10-5-1,nfs_s/svd/ws/scripts () tree -a work
work
└── 24
    └── 0b94aa028934c3e5983d05d08bf80a
        ├── .command.begin    <-  sentinel file when task starts
        ├── .command.err      <-  command stderr
        ├── .command.log      <-  log output from the executor; could (only) contain command stderr
        ├── .command.out      <-  command stdout
        ├── .command.run      <-  contains tracing code, environment set-up e.g. singularity
        ├── .command.sh       <-  contains the code in our shell: section, nothing else
        ├── .exitcode         <-  what it says on the tin
        ├── chunk_aa
        ├── chunk_ab
        ├── chunk_ac          >-  the outputs of our shell: section
        ├── chunk_ad
        └── chunk_ae
```

If something goes wrong during a pipeline execution,
you can change to the directory and inspect `.command.err`, `.command.out`, and `.command.log`, and
also inspect any input files to the process. These are not present in this example, but will be
symbolic links to files in other task directories if present (see later examples).

Issue `bash .command.run` to re-run the command interactively. You can make changes to `.command.sh`
or change your environment if useful.


###  Scripts

Bigger scripts can be put in a `bin` directory at the same level as the nextflow script that is being run.
This is how nextfow pipelines are structured in git repositories. Scripts and programs that are in your
environment are also available of course. The above script can be run like this:

```
params.str    = 'the quick brown dog jumps over a lazy dog'
params.outdir = 'results'

process splitLetters {

    publishDir "${params.outdir}/1", mode: 'link'

    output:
    file 'chunk_*'

    shell:
    '''
    myscript.sh "!{params.str}"
    '''
}
```

As we have the script `myscript.sh` in the bin directory. Note that it does not need to be in the PATH
variable. Any type of script (Python, R, Julia et cetera) can be used.


###  Using multiple CPUs

If the process can use multiple CPUs you have to tell it how many using the
Nextflow `task` object. Processes do not magically know this. These are
examples from `shell:` sections in our rnaseq pipeline:

```
samtools merge -@ !{task.cpus} -f !{outcramfile} !{crams}

fastqc -t !{task.cpus} -q !{reads}

bracer assemble -p !{task.cpus} -s !{spec} out-!{samplename} out_asm f1 f2

  STAR --genomeDir !{index} \\
      --sjdbGTFfile !{gtf} \\
      --readFilesIn !{reads} --readFilesCommand zcat \\
      --runThreadN !{task.cpus} \\
      --twopassMode Basic \\
      --outWigType bedGraph \\
      --outSAMtype BAM SortedByCoordinate \\
      --outSAMunmapped Within \\
      --runDirPerm All_RWX \\
      --quantMode GeneCounts \\
      --outFileNamePrefix !{samplename}.
```

###  Understanding channels and files is key to working with Nextflow

*   Start small
*   Stay small
*   Small building blocks
*   (small) Toy examples to create a skeleton channel structure

### [Two processes communicating](scripts/2_connect_processes.nf)

```
params.str    = 'the quick brown dog jumps over a lazy dog'
params.outdir = 'results'

process splitLetters {

    publishDir "${params.outdir}/2", mode: 'link'

    output: file 'chunk_*' into ch_letters

    shell:
    '''
    printf '!{params.str}' | split -b 10 - chunk_
    '''
}

process convertToUpper {

    publishDir "${params.outdir}/2", mode: 'link'

    input: file x from ch_letters.flatten()     // -------- parallelisation! ------- //

    output: file('*.txt') into ch_morestuff

    shell:
    '''
    cat !{x} | tr '[a-z]' '[A-Z]' > hw.!{task.index}.txt
    '''
}

ch_morestuff.view()                             // -------- useful inspection ------ //
```

In this example we use `!{task.index}` to make the output file names unique, but will
normally not be necessary; meaningful file names can be constructed from a sample ID for
example, as shown later here.

Example invocations:
```
nextflow run 1_a_process.nf -ansi-log false      # because we are using 'view()' on a channel
nextflow run 1_a_process.nf -ansi-log false --str 'pack my box with five dozen liquor jugs'
```

###  On-disk organisation by Nextflow

```
work
├── 14
│   └── 189a1698db6c02c0b49331ccc5e0f9
│       ├── .command.begin
│       ├── .command.err
│       ├── .command.log
│       ├── .command.out
│       ├── .command.run
│       ├── .command.sh
│       ├── .exitcode
│       ├── chunk_aa -> /nfs/users/nfs_s/svd/ws/scripts/work/2a/921c9654039200cf6bd8947f2c549e/chunk_aa
│       └── hw.1.txt
├── 2a
│   └── 921c9654039200cf6bd8947f2c549e
│       ├── .command.begin
│       ├── .command.err
│       ├── .command.log
│       ├── .command.out
│       ├── .command.run
│       ├── .command.sh
│       ├── .exitcode
│       ├── chunk_aa
│       ├── chunk_ab
│       └── chunk_ac
├── 3e
│   └── a151050f95bb3f6ab87c458ac98541
│       ├── .command.begin
│       ├── .command.err
│       ├── .command.log
│       ├── .command.out
│       ├── .command.run
│       ├── .command.sh
│       ├── .exitcode
│       ├── chunk_ab -> /nfs/users/nfs_s/svd/ws/scripts/work/2a/921c9654039200cf6bd8947f2c549e/chunk_ab
│       └── hw.2.txt
└── e9
    └── ab41e17c2dd5ff570dbe87b9071b3e
        ├── .command.begin
        ├── .command.err
        ├── .command.log
        ├── .command.out
        ├── .command.run
        ├── .command.sh
        ├── .exitcode
        ├── chunk_ac -> /nfs/users/nfs_s/svd/ws/scripts/work/2a/921c9654039200cf6bd8947f2c549e/chunk_ac
        └── hw.3.txt
```

### [Merge multiple inputs](scripts/3_process_merge.nf)


```
params.str    = 'the quick brown dog jumps over a lazy dog'
params.outdir = 'results'

process splitLetters {
    publishDir "${params.outdir}/3", mode: 'link'
    output: file 'chunk_*' into ch_letters

    shell: 'printf "!{params.str}" | split -b 10 - chunk_'
}
process convertToUpper {
    publishDir "${params.outdir}/3", mode: 'link'

    input: file x from ch_letters.flatten()
    output: file('*.txt') into ch_merge

    shell: 'cat !{x} | tr "[a-z]" "[A-Z]" > hw.!{task.index}.txt'
}
process mergeData {
    echo true
    publishDir "${params.outdir}/3", mode: 'link'

    input: file inputs from ch_merge.collect()
    output: file('summary.txt')

    shell:
    '''
    echo "I have files !{inputs}"
    md5sum !{inputs} > summary.txt
    ''' 
}
```

Invocation:
```
nextflow run 3_process_merge.nf -ansi-log false
```


### [Read fastq files with sample ID](scripts/4_fastq_files.nf)

```
Channel
    .fromFilePairs('inputs/*.r_{1,2}.fastq')
    .view()
    .set { ch_fastq_align }

process alignReads {
  echo true

  input: set val(sample_id), file(fastqs) from ch_fastq_align

  output: set val(sample_id), file('*.bam') into ch_bam

  shell:
  f1 = fastqs[0]
  f2 = fastqs[1]
  '''
  echo "align reads input: !{sample_id} !{fastqs}"
  echo "Equivalently: !{sample_id} f1 !{f1} f2 !{f2}"

  # please pretend this is an alignment program
  cat !{fastqs} | gzip -c > !{sample_id}.bam
  '''
}

ch_bam.view()
```

Invocation:
```
nextflow run 4_fastq_files.nf -ansi-log false
```

### [Import data using manifest file; split data, compute, merge back](scripts/5_manifest_and_chunk.nf)

Invocation:
```
nextflow run 5_manifest_and_chunk.nf --datadir $PWD/inputs -ansi-log false
```

```
params.samplefile = 'manifest.txt'
params.datadir = ''
params.chunksize = 35
params.outdir = 'results'
Channel.fromPath(params.samplefile).set { samplelist }

process import_data {

  when: params.datadir != ''

  input: set val(sample_id), val(fname) from samplelist.splitCsv(sep: '\t').view { "splitcsv: $it" }

  output: set val(sample_id), file("${sample_id}.*") into ch_chunky  // for each sample ID,
                                                                     // split its data into chunks
  shell:
  '''
  filename=!{params.datadir}/!{fname}

  if [[ ! -e $filename ]]; then
    echo "File $filename not found!"
    false
  fi
  split -l !{params.chunksize} $filename !{sample_id}.
  '''
}

ch_chunky
  .view { "chunk $it" }
  .transpose()                                                       // separate the chunks
  .view { "transpose $it" }                                          // standard idiom; a pattern
  .set { ch_chunks }


process do_a_sample_chunk {
  echo true

  input: set val(sample_id), file(chunk) from ch_chunks

  output: set val(sample_id), file('*.max') into ch_scatter

  shell:
  '''
  echo "parallel execution: !{sample_id} !{chunk}"
  sort -n !{chunk} | tail -n 1 > !{chunk}.max
  '''
}

process samples_gather {
  echo true

  publishDir "${params.outdir}/5", mode: 'link'

  input: set val(sample_id), file(maxes) from ch_scatter.groupTuple()     // re-unite the chunks
  output: file('*.integrated')

  shell:
  '''
  echo "integrate: !{sample_id} !{maxes}"
  cat !{maxes} > !{sample_id}.integrated
  '''
}
```


###  Github repositories

If something looks like a github repository, Nextflow will download it.

```
nextflow run cellgeni/rnaseq --fastqdir adir --samplefile manifest.txt
```

will clone the repository and run the file `main.nf` in that repository.
Any custom scripts that are needed are present in the `bin` directory in the repository.

### Further notes/topics


* `shell:` is a relatively new feature, many pipelines still use `script:`. They are
  identical except that `shell` has much cleaner variable interpolation. Use `shell:`.
* Nextflow is based on Java/groovy, no need to know either
* DSL2
  - allows re-use of processes and sub-workflows
  - introduces abstraction layer; a very compact representation of workflow
* executors (enabled configured with different profiles)
* process configuration (memory/cpus/failure mode)
* software environments: containers (docker/singularity), conda


  For these:

* Nextflow documentation
* Look at existing repositories
* Ask NF people on Mattermost, Gitter, IRL, via e-mail, post ...


## Documentation, contact, examples
  [Nextflow documentation](https://www.nextflow.io/docs/latest/getstarted.html)  
  [Previous cellgeni workshop](https://github.com/cellgeni/nf-workshop)

  [Cellgen mattermost channel](https://mattermost.sanger.ac.uk/cellgeninf/channels/town-square)  
  [Stijn on mattermost](https://mattermost.sanger.ac.uk/cellgeninf/messages/@svd)  
  [Nextflow gitter channel](https://gitter.im/nextflow-io/nextflow)  
  [Nextflow sanger support gitter channel](https://gitter.im/nf-support-sanger/Lobby)  

  [Workflow mailing list](https://lists.sanger.ac.uk/mailman/listinfo/workflows)  
  Workflow coffee morning - Mondays 10:30, bi-weekly, announced on mailing list  
  Cellgen coffee stand-up - Wednessdays 14:00 Morgan atrium  

  Existing patterns and examples  
  [Nextflow patterns](https://github.com/nextflow-io/patterns)  
  [Stijn's nextflow patterns](https://github.com/micans/nextflow-idioms)  

  Existing NF repositories  
  [cellgeni RNAseq](https://github.com/cellgeni/rnaseq)  
  [cellgeni data sharing](https://github.com/cellgeni/guitar)  
  [cellgeni atac-seq (devel)](https://github.com/cellgeni/cellatac)  

### NF-core!
  [A community effort to collect a curated set of analysis pipelines built using Nextflow](https://nf-co.re/)



