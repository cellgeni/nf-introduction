
params.str    = 'the quick brown dog jumps over a lazy dog'
params.outdir = 'results'

process splitLetters {

    publishDir "${params.outdir}/2", mode: 'link'

    output:
    file 'chunk_*' into ch_letters

    shell:
    '''
    printf '!{params.str}' | split -b 15 - chunk_
    '''
}

process convertToUpper {

    publishDir "${params.outdir}/2", mode: 'link'

    input:
    file x from ch_letters.flatten()              // -------- parallelisation! ------- //

    output:
    file('*.txt') into ch_morestuff

    shell:
    '''
    cat !{x} | tr '[a-z]' '[A-Z]' > hw.!{task.index}.txt
    '''
}

ch_morestuff.view()

