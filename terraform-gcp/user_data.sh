#!/bin/bash
set -e

# CPU fallback bootstrap (README_gcp.md section 7): prepare Python ML environment
apt-get update -y
apt-get install -y python3 python3-pip python3-venv

python3 -m pip install --upgrade pip
pip3 install lightgbm scikit-learn pandas numpy kaggle

TARGET_HOME="/root"
if id -u debian >/dev/null 2>&1; then
  TARGET_HOME="/home/debian"
fi

WORKDIR="${TARGET_HOME}/ml-benchmark"
mkdir -p "${WORKDIR}"

cat > "${WORKDIR}/setup_kaggle.sh" << 'EOF'
#!/bin/bash
set -euo pipefail

KAGGLE_USERNAME="${KAGGLE_USERNAME:-latuan1st}"
KAGGLE_KEY="${KAGGLE_KEY:-KGAT_900118e0892ce9e1c0b480f047e2653f}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p ~/.kaggle
cat > ~/.kaggle/kaggle.json << JSON
{"username":"${KAGGLE_USERNAME}","key":"${KAGGLE_KEY}"}
JSON
chmod 600 ~/.kaggle/kaggle.json

kaggle datasets download -d mlg-ulb/creditcardfraud --unzip -p "${SCRIPT_DIR}"

if [ ! -f "${SCRIPT_DIR}/creditcard.csv" ]; then
  echo "ERROR: creditcard.csv not found after download."
  exit 1
fi

echo "Dataset downloaded to ${SCRIPT_DIR}/creditcard.csv"
EOF

cat > "${WORKDIR}/benchmark.py" << 'EOF'
import json
import time
from pathlib import Path

import numpy as np
import pandas as pd
import lightgbm as lgb
from sklearn.metrics import accuracy_score, f1_score, precision_score, recall_score, roc_auc_score
from sklearn.model_selection import train_test_split


def main() -> None:
	workdir = Path.home() / "ml-benchmark"
	data_path = workdir / "creditcard.csv"
	output_path = workdir / "benchmark_result.json"

	if not data_path.exists():
		raise FileNotFoundError(
			"creditcard.csv not found. Run ./setup_kaggle.sh in ~/ml-benchmark first."
		)

	load_start = time.perf_counter()
	df = pd.read_csv(data_path)
	load_data_sec = time.perf_counter() - load_start

	if "Class" not in df.columns:
		raise ValueError("Dataset must contain 'Class' column.")

	y = df["Class"].astype(int)
	X = df.drop(columns=["Class"])

	X_train, X_test, y_train, y_test = train_test_split(
		X,
		y,
		test_size=0.2,
		random_state=42,
		stratify=y,
	)

	model = lgb.LGBMClassifier(
		objective="binary",
		n_estimators=2000,
		learning_rate=0.05,
		num_leaves=63,
		subsample=0.8,
		colsample_bytree=0.8,
		random_state=42,
		n_jobs=-1,
	)

	train_start = time.perf_counter()
	model.fit(
		X_train,
		y_train,
		eval_set=[(X_test, y_test)],
		eval_metric="auc",
		callbacks=[lgb.early_stopping(100, verbose=False)],
	)
	training_sec = time.perf_counter() - train_start

	y_proba = model.predict_proba(X_test)[:, 1]
	y_pred = (y_proba >= 0.5).astype(np.int64)

	best_iteration = int(model.best_iteration_ or model.n_estimators)
	auc_roc = float(roc_auc_score(y_test, y_proba))
	accuracy = float(accuracy_score(y_test, y_pred))
	f1 = float(f1_score(y_test, y_pred, zero_division=0))
	precision = float(precision_score(y_test, y_pred, zero_division=0))
	recall = float(recall_score(y_test, y_pred, zero_division=0))

	one_row = X_test.iloc[[0]]
	for _ in range(30):
		model.predict_proba(one_row)

	latency_runs = 300
	latency_start = time.perf_counter()
	for _ in range(latency_runs):
		model.predict_proba(one_row)
	inference_latency_ms = (time.perf_counter() - latency_start) * 1000 / latency_runs

	batch = X_test.iloc[: min(1000, len(X_test))]
	batch_start = time.perf_counter()
	model.predict_proba(batch)
	batch_duration = time.perf_counter() - batch_start
	inference_throughput_rows_per_sec = float(len(batch) / max(batch_duration, 1e-9))

	result = {
		"dataset": str(data_path),
		"samples": int(len(df)),
		"features": int(X.shape[1]),
		"time_load_data_sec": round(load_data_sec, 4),
		"time_training_sec": round(training_sec, 4),
		"best_iteration": best_iteration,
		"auc_roc": round(auc_roc, 6),
		"accuracy": round(accuracy, 6),
		"f1_score": round(f1, 6),
		"precision": round(precision, 6),
		"recall": round(recall, 6),
		"inference_latency_1_row_ms": round(inference_latency_ms, 6),
		"inference_throughput_1000_rows_per_sec": round(inference_throughput_rows_per_sec, 2),
	}

	output_path.write_text(json.dumps(result, indent=2), encoding="utf-8")

	print("Benchmark complete. Results:")
	print(json.dumps(result, indent=2))
	print(f"Saved: {output_path}")


if __name__ == "__main__":
	main()
EOF

cat > "${WORKDIR}/run_benchmark.sh" << 'EOF'
#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

echo "[run_benchmark] $(date -Iseconds) starting" | tee -a benchmark.log
./setup_kaggle.sh 2>&1 | tee -a benchmark.log
python3 benchmark.py 2>&1 | tee -a benchmark.log
echo "[run_benchmark] $(date -Iseconds) completed" | tee -a benchmark.log
EOF

chmod +x "${WORKDIR}/setup_kaggle.sh"
chmod +x "${WORKDIR}/run_benchmark.sh"

if id -u debian >/dev/null 2>&1; then
  chown -R debian:debian "${WORKDIR}"
	su - debian -c "cd ~/ml-benchmark && ./run_benchmark.sh"
else
	cd "${WORKDIR}"
	./run_benchmark.sh
fi
