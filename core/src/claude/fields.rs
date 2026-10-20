//! Leitura tolerante de JSON: campo ausente ou de outro tipo vira `None`,
//! sem derrubar o resto do arquivo.

use serde_json::Value;

pub fn text(value: &Value, key: &str) -> Option<String> {
    value.get(key)?.as_str().map(str::to_string)
}

pub fn int(value: &Value, key: &str) -> Option<i64> {
    value.get(key)?.as_i64()
}

pub fn count(value: &Value, key: &str) -> u64 {
    value.get(key).and_then(Value::as_u64).unwrap_or(0)
}
