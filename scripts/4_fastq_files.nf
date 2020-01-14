
Channel
    .fromFilePairs('inputs/*.r_{1,2}.fastq')
    .view()
    .set { ch_fastq_align }

process countReads {
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

