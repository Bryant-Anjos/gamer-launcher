use launcher_core::stats::{DiskInfo, StatsSampler, percent, pick_main_disk};

fn disk(mount: &str, total: u64, available: u64) -> DiskInfo {
    DiskInfo {
        mount_point: mount.into(),
        total,
        available,
    }
}

#[test]
fn percent_is_used_over_total() {
    assert_eq!(percent(50, 200), 25.0);
    assert_eq!(percent(200, 200), 100.0);
}

#[test]
fn percent_of_nothing_is_zero() {
    assert_eq!(percent(10, 0), 0.0);
}

#[test]
fn main_disk_is_the_root_mount() {
    let disks = [disk("/boot", 1_000, 900), disk("/", 500, 100)];

    assert_eq!(pick_main_disk(&disks), Some(&disks[1]));
}

#[test]
fn without_root_the_biggest_disk_wins() {
    let disks = [disk("/mnt/a", 100, 10), disk("/mnt/b", 900, 10)];

    assert_eq!(pick_main_disk(&disks), Some(&disks[1]));
}

#[test]
fn no_disks_means_no_main_disk() {
    assert_eq!(pick_main_disk(&[]), None);
}

#[test]
fn disk_usage_is_total_minus_available() {
    assert_eq!(disk("/", 500, 120).used(), 380);
    assert_eq!(disk("/", 100, 300).used(), 0);
}

#[test]
fn a_real_sample_is_consistent() {
    let mut sampler = StatsSampler::new();

    let stats = sampler.sample();

    assert!(stats.ram_total > 0);
    assert!(stats.ram_used <= stats.ram_total);
    assert!((0.0..=100.0).contains(&stats.cpu_percent));
    assert!(stats.disk_used <= stats.disk_total);
    assert!((0.0..=100.0).contains(&stats.ram_percent()));
    assert!((0.0..=100.0).contains(&stats.disk_percent()));
}
