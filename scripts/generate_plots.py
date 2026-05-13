#!/usr/bin/env python3
"""
generate_plots.py — Performance Analysis Plot Generator
========================================================
Generates all figures for the RISC-V Sv32 TLB project report from
FPGA ILA-captured data. Outputs PNG and PDF to docs/figures/.

Usage:
    cd scripts
    python generate_plots.py
"""

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import matplotlib.ticker as mticker
import numpy as np
import os

# Output directory (relative to repo root)
script_dir = os.path.dirname(os.path.abspath(__file__))
repo_root = os.path.dirname(script_dir)
out_dir = os.path.join(repo_root, 'docs', 'figures')
os.makedirs(out_dir, exist_ok=True)

# ============================================================================
#  FPGA ILA Data (captured on Zybo Z7-10 at 62.5 MHz)
# ============================================================================
tests = ['T1\n(1 pg)', 'T2\n(4 pg)', 'T3\n(8 pg)', 'T4\n(16 pg)']
pages = [1, 4, 8, 16]
cycles_vm = [160, 475, 4135, 8215]

# Baseline: base RV32I CPU (2-cycle branch penalty, formula: 60N+38)
baseline = [98, 278, 518, 998]
overhead_cyc = [c - b for c, b in zip(cycles_vm, baseline)]
overhead_pct = [100.0 * o / c for o, c in zip(overhead_cyc, cycles_vm)]

hit_rate_obs = [90.9, 90.9, 50.0, 50.0]
logical_hit = [90.0, 90.0, 0.0, 0.0]
emat = [5.2, 5.2, 47.0, 47.0]

# ============================================================================
#  Styling
# ============================================================================
c_primary = '#2563EB'
c_danger = '#DC2626'
c_success = '#16A34A'
c_amber = '#D97706'
c_purple = '#7C3AED'
c_gray = '#6B7280'
c_bg = '#F8FAFC'

plt.rcParams.update({
    'font.family': 'serif', 'font.size': 11, 'axes.titlesize': 13,
    'axes.labelsize': 12, 'figure.dpi': 300, 'savefig.dpi': 300,
    'savefig.bbox': 'tight', 'axes.facecolor': c_bg, 'figure.facecolor': 'white',
    'axes.grid': True, 'grid.alpha': 0.3, 'grid.linestyle': '--',
})

x = np.arange(len(tests))

# ============================================================================
#  PLOT 1: Overhead %
# ============================================================================
fig, ax = plt.subplots(figsize=(6, 4))
colors = [c_success, c_success, c_danger, c_danger]
bars = ax.bar(tests, overhead_pct, color=colors, edgecolor='white', linewidth=1.5, width=0.6)
for bar, val in zip(bars, overhead_pct):
    ax.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 1.5,
            f'{val:.1f}%', ha='center', va='bottom', fontweight='bold', fontsize=11)
ax.axvline(x=1.5, color=c_gray, linestyle=':', linewidth=1.5, alpha=0.7)
ax.text(1.5, 95, '← fits in TLB | exceeds TLB →', ha='center', fontsize=9, color=c_gray, style='italic')
ax.set_ylabel('Translation Overhead (%)')
ax.set_title('Address Translation Overhead vs Working Set Size')
ax.set_ylim(0, 105)
ax.yaxis.set_major_formatter(mticker.PercentFormatter())
plt.tight_layout()
plt.savefig(os.path.join(out_dir, 'overhead_pct.png'))
plt.savefig(os.path.join(out_dir, 'overhead_pct.pdf'))
plt.close()
print(f"Plot 1: overhead = {[f'{v:.1f}%' for v in overhead_pct]}")

# ============================================================================
#  PLOT 2: Cycle Breakdown
# ============================================================================
fig, ax = plt.subplots(figsize=(6, 4))
bars_base = ax.bar(x, baseline, 0.6, label='Useful computation', color=c_primary, edgecolor='white', linewidth=1.5)
bars_over = ax.bar(x, overhead_cyc, 0.6, bottom=baseline, label='Translation overhead', color=c_danger, edgecolor='white', linewidth=1.5)
for i, (b, o, total, pct) in enumerate(zip(baseline, overhead_cyc, cycles_vm, overhead_pct)):
    ax.text(i, total + 150, f'{total}', ha='center', fontsize=9, fontweight='bold')
    if o > 300:
        ax.text(i, b + o/2, f'{pct:.1f}%', ha='center', va='center', fontsize=10, fontweight='bold', color='white')
ax.set_xticks(x)
ax.set_xticklabels(tests)
ax.set_ylabel('Total Cycles')
ax.set_title('Cycle Breakdown: Useful Computation vs Translation Overhead')
ax.legend(loc='upper left', framealpha=0.9)
ax.set_ylim(0, 9500)
plt.tight_layout()
plt.savefig(os.path.join(out_dir, 'cycle_breakdown.png'))
plt.savefig(os.path.join(out_dir, 'cycle_breakdown.pdf'))
plt.close()
print("Plot 2: cycle_breakdown saved")

# ============================================================================
#  PLOT 3: Hit Rate
# ============================================================================
fig, ax = plt.subplots(figsize=(6, 4))
ax.plot(pages, hit_rate_obs, 'o-', color=c_primary, linewidth=2, markersize=8, label='Observed hit rate', zorder=5)
ax.plot(pages, logical_hit, 's--', color=c_danger, linewidth=2, markersize=8, label='Logical hit rate', zorder=5)
ax.annotate('Replay inflates\nobserved rate', xy=(8, 50), xytext=(12, 65),
            fontsize=9, color=c_gray, style='italic', arrowprops=dict(arrowstyle='->', color=c_gray, lw=1.5))
ax.axvline(x=4, color=c_amber, linestyle=':', linewidth=2, alpha=0.7)
ax.text(4.3, 15, 'TLB capacity\n(4 entries)', fontsize=9, color=c_amber)
ax.set_xlabel('Working Set Size (pages)')
ax.set_ylabel('Hit Rate (%)')
ax.set_title('TLB Hit Rate: Observed vs Logical')
ax.set_xticks(pages)
ax.set_ylim(-5, 105)
ax.legend(loc='center right', framealpha=0.9)
plt.tight_layout()
plt.savefig(os.path.join(out_dir, 'hit_rate.png'))
plt.savefig(os.path.join(out_dir, 'hit_rate.pdf'))
plt.close()
print("Plot 3: hit_rate saved")

# ============================================================================
#  PLOT 4: VM vs Baseline
# ============================================================================
fig, ax = plt.subplots(figsize=(6, 4))
ax.plot(pages, cycles_vm, 'o-', color=c_primary, linewidth=2.5, markersize=10, label='With TLB (FPGA measured)', zorder=5)
ax.plot(pages, baseline, 's--', color=c_success, linewidth=2, markersize=8, label='Base CPU (no TLB)', zorder=5)
ax.fill_between(pages, baseline, cycles_vm, alpha=0.15, color=c_danger, label='Translation overhead')
for p, c in zip(pages, cycles_vm):
    ax.annotate(f'{c}', xy=(p, c), xytext=(0, 10), textcoords='offset points', ha='center', fontsize=9, fontweight='bold')
for p, b in zip(pages, baseline):
    ax.annotate(f'{b}', xy=(p, b), xytext=(0, -15), textcoords='offset points', ha='center', fontsize=8, color=c_success)
ax.set_xlabel('Working Set Size (pages)')
ax.set_ylabel('Total Cycles')
ax.set_title('Execution Time: TLB-Enabled vs Base CPU')
ax.set_xticks(pages)
ax.legend(loc='upper left', framealpha=0.9)
plt.tight_layout()
plt.savefig(os.path.join(out_dir, 'cycles_comparison.png'))
plt.savefig(os.path.join(out_dir, 'cycles_comparison.pdf'))
plt.close()
print("Plot 4: cycles_comparison saved")

# ============================================================================
#  PLOT 5: EMAT
# ============================================================================
fig, ax = plt.subplots(figsize=(6, 4))
ax.bar(x - 0.15, emat, 0.3, label='EMAT (with TLB)', color=c_danger, edgecolor='white')
ax.bar(x + 0.15, [1,1,1,1], 0.3, label='Ideal (no translation)', color=c_success, edgecolor='white')
for i, val in enumerate(emat):
    ax.text(i - 0.15, val + 1, f'{val}', ha='center', fontsize=10, fontweight='bold')
ax.axvline(x=1.5, color=c_gray, linestyle=':', linewidth=1.5, alpha=0.7)
ax.text(1.5, 50, '← fits | thrashing →', ha='center', fontsize=9, color=c_gray, style='italic')
ax.set_xticks(x)
ax.set_xticklabels(tests)
ax.set_ylabel('EMAT (cycles per access)')
ax.set_title('Effective Memory Access Time')
ax.legend(loc='upper left', framealpha=0.9)
ax.set_ylim(0, 55)
plt.tight_layout()
plt.savefig(os.path.join(out_dir, 'emat.png'))
plt.savefig(os.path.join(out_dir, 'emat.pdf'))
plt.close()
print("Plot 5: emat saved")

# ============================================================================
#  PLOT 6: Slowdown Factor
# ============================================================================
fig, ax = plt.subplots(figsize=(6, 4))
slowdown = [c/b for c, b in zip(cycles_vm, baseline)]
bars = ax.bar(tests, slowdown, color=[c_success, c_success, c_danger, c_danger], edgecolor='white', linewidth=1.5, width=0.6)
for bar, val in zip(bars, slowdown):
    ax.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 0.1,
            f'{val:.1f}×', ha='center', va='bottom', fontweight='bold', fontsize=11)
ax.axhline(y=1, color=c_gray, linestyle='--', linewidth=1, alpha=0.5)
ax.axvline(x=1.5, color=c_gray, linestyle=':', linewidth=1.5, alpha=0.7)
ax.set_ylabel('Slowdown Factor (×)')
ax.set_title('Execution Slowdown Due to Address Translation')
ax.set_ylim(0, 10)
plt.tight_layout()
plt.savefig(os.path.join(out_dir, 'slowdown.png'))
plt.savefig(os.path.join(out_dir, 'slowdown.pdf'))
plt.close()
print("Plot 6: slowdown saved")

# ============================================================================
#  PLOT 7: Miss Penalty (constant 46 cycles)
# ============================================================================
fig, ax = plt.subplots(figsize=(6, 4))
miss_penalty = [46, 46, 46, 46]
bars = ax.bar(tests, miss_penalty, color=c_purple, edgecolor='white', linewidth=1.5, width=0.6)
for bar, val in zip(bars, miss_penalty):
    ax.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 0.8,
            f'{val}', ha='center', va='bottom', fontweight='bold', fontsize=12)
ax.axhline(y=46, color=c_gray, linestyle='--', linewidth=1, alpha=0.5)
ax.set_ylabel('Cycles per TLB Miss')
ax.set_title('TLB Miss Penalty (Constant Across Configurations)')
ax.set_ylim(0, 55)
plt.tight_layout()
plt.savefig(os.path.join(out_dir, 'miss_penalty.png'))
plt.savefig(os.path.join(out_dir, 'miss_penalty.pdf'))
plt.close()
print("Plot 7: miss_penalty saved")

# ============================================================================
#  Summary
# ============================================================================
print(f"\nBaseline: {baseline}")
print(f"Overhead cycles: {overhead_cyc}")
print(f"Overhead %: {[f'{v:.1f}' for v in overhead_pct]}")
print(f"Slowdown: {[f'{v:.1f}x' for v in slowdown]}")
print(f"\nAll plots saved to: {out_dir}")
