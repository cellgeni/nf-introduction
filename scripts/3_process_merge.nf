
params.str    = 'the quick brown dog jumps over a lazy dog'
params.outdir = 'results'

process splitLetters {

    tag "letter"

    publishDir "${params.outdir}/3", mode: 'link'

    output:
    file 'chunk_*' into ch_letters

    shell:
    '''
    printf '!{params.str}' | split -b 10 - chunk_
    '''
}

process convertToUpper {

    tag "upper"

    publishDir "${params.outdir}/3", mode: 'link'

    input:
    file x from ch_letters.flatten()

    output:
    file('*.txt') into ch_md5sum

    shell:
    '''
    cat !{x} | tr '[a-z]' '[A-Z]' > hw.!{task.index}.txt
    '''
}

process md5sum {

    echo true

    publishDir "${params.outdir}/3", mode: 'link'

    input:
    file inputs from ch_md5sum.collect()

    output:
    file('summary.txt')

    shell:
    '''
    echo "I have files !{inputs}"
    md5sum !{inputs} > summary.txt
    ''' 
}

