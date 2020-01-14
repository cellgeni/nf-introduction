
params.str    = 'the quick brown dog jumps over a lazy dog'
params.outdir = 'results'

process splitLetters {

    tag "letters"

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

