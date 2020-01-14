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

  output: set val(sample_id), file('*.max') into ch_reduced

  shell:
  '''
  echo "parallel execution: !{sample_id} !{chunk}"
  sort -n !{chunk} | tail -n 1 > !{chunk}.max
  '''
}

process samples_result {
  echo true

  publishDir "${params.outdir}/5", mode: 'link'

  input: set val(sample_id), file(maxes) from ch_reduced.groupTuple()     // re-unite the chunks
  output: file('*.integrated')

  shell:
  '''
  echo "integrate: !{sample_id} !{maxes}"
  cat !{maxes} > !{sample_id}.integrated
  '''
}
