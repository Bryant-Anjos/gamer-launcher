use std::path::{Path, PathBuf};
use sysinfo::{Disks, System};

const MAX_PERCENT: f32 = 100.0;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct DiskInfo {
    pub mount_point: PathBuf,
    pub total: u64,
    pub available: u64,
}

impl DiskInfo {
    pub fn used(&self) -> u64 {
        self.total.saturating_sub(self.available)
    }
}

#[derive(Debug, Clone, PartialEq)]
pub struct SystemStats {
    pub cpu_percent: f32,
    pub ram_used: u64,
    pub ram_total: u64,
    pub disk_used: u64,
    pub disk_total: u64,
}

impl SystemStats {
    pub fn ram_percent(&self) -> f32 {
        percent(self.ram_used, self.ram_total)
    }

    pub fn disk_percent(&self) -> f32 {
        percent(self.disk_used, self.disk_total)
    }
}

pub fn percent(used: u64, total: u64) -> f32 {
    if total == 0 {
        return 0.0;
    }
    ((used as f64 / total as f64 * 100.0) as f32).min(MAX_PERCENT)
}

/// O disco "principal" é a raiz do sistema; sem ela, o maior disco.
pub fn pick_main_disk(disks: &[DiskInfo]) -> Option<&DiskInfo> {
    disks
        .iter()
        .find(|disk| disk.mount_point == Path::new("/"))
        .or_else(|| disks.iter().max_by_key(|disk| disk.total))
}

/// Mantém o estado do sysinfo entre leituras: o uso de CPU só é
/// significativo a partir da segunda chamada de `sample`.
pub struct StatsSampler {
    system: System,
    disks: Disks,
}

impl StatsSampler {
    pub fn new() -> Self {
        Self {
            system: System::new(),
            disks: Disks::new_with_refreshed_list(),
        }
    }

    pub fn sample(&mut self) -> SystemStats {
        self.system.refresh_cpu_usage();
        self.system.refresh_memory();
        self.disks.refresh(true);

        let disks: Vec<DiskInfo> = self
            .disks
            .iter()
            .map(|disk| DiskInfo {
                mount_point: disk.mount_point().to_path_buf(),
                total: disk.total_space(),
                available: disk.available_space(),
            })
            .collect();
        let main = pick_main_disk(&disks);

        SystemStats {
            cpu_percent: self.system.global_cpu_usage().clamp(0.0, MAX_PERCENT),
            ram_used: self.system.used_memory(),
            ram_total: self.system.total_memory(),
            disk_used: main.map_or(0, DiskInfo::used),
            disk_total: main.map_or(0, |disk| disk.total),
        }
    }
}

impl Default for StatsSampler {
    fn default() -> Self {
        Self::new()
    }
}
