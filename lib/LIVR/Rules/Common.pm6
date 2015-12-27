unit package LIVR::Rules::Common;

our sub required([], $builders) {
    return sub ($value, $all-values, $output is rw) {
        return 'REQUIRED' if !$value.defined || $value eq '';
    };
}

our sub not_empty([], $builders) {
    return sub ($value, $all-values, $output is rw) {
        return "CANNOT_BE_EMPTY" if $value.defined && $value eq '';
    };
}

our sub not_empty_list([], $builders) {
    return sub ($list, $all-values, $output is rw) {
        return 'CANNOT_BE_EMPTY' if !$list.defined || $list eq '';
        return 'WRONG_FORMAT' unless $list ~~ Array;
        return 'CANNOT_BE_EMPTY' unless $list.elems;
        return;
    }
}
