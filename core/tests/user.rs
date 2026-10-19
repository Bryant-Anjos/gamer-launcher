use launcher_core::user::first_name_from_passwd;

const PASSWD: &str = "\
root:x:0:0:root:/root:/bin/bash
ana:x:1000:1000:Ana Souza Lima,,,:/home/ana:/bin/bash
nogecos:x:1001:1001::/home/nogecos:/bin/bash
spaces:x:1002:1002:   ,,,:/home/spaces:/bin/bash
";

#[test]
fn the_first_word_of_the_real_name_is_used() {
    assert_eq!(
        first_name_from_passwd(PASSWD, "ana").as_deref(),
        Some("Ana")
    );
}

#[test]
fn users_without_a_real_name_have_no_first_name() {
    assert_eq!(first_name_from_passwd(PASSWD, "nogecos"), None);
    assert_eq!(first_name_from_passwd(PASSWD, "spaces"), None);
}

#[test]
fn unknown_users_have_no_first_name() {
    assert_eq!(first_name_from_passwd(PASSWD, "ghost"), None);
    assert_eq!(first_name_from_passwd(PASSWD, ""), None);
}

#[test]
fn a_user_name_that_is_a_prefix_of_another_does_not_match() {
    assert_eq!(first_name_from_passwd(PASSWD, "brill"), None);
}

#[test]
fn malformed_lines_are_skipped() {
    let text = "garbage\nana:x:1:1:Ana Paula:/home/ana:/bin/sh\n";

    assert_eq!(first_name_from_passwd(text, "ana").as_deref(), Some("Ana"));
    assert_eq!(first_name_from_passwd(text, "garbage"), None);
}
