#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/printk.h>
#include <linux/proc_fs.h>
#include <linux/seq_file.h>
#include <linux/time.h>

#define PROC_NAME "venus_lab"

/*
  Реальные астрономические данные (по состоянию на 2025 г.)
  Венера вошла в созвездие Стрельца 30 декабря 2025.
  Следующее вхождение в Стрелец ожидается 12 декабря 2027.
  Источники: Stellarium, TheSkyLive, JPL Horizons приблеженно
  я считаю, что "возврат в текущее созвездие" — это следующая дата:
    12 декабря 2027, 00:00 UTC → timestamp = 1828512000
 */

static int venus_proc_show(struct seq_file *m, void *v)
{
    const time64_t next_return_ts = 1828512000LL; // 2027-12-12 00:00:00 UTC 
    time64_t now = ktime_get_real_seconds();

    if (now >= next_return_ts) {
        seq_printf(m,
            "Венера уже вернулась в созвездие Стрельца!\n"
            "Следующий возврат будет ориентировочно через ~2 года.\n");
    } else {
        time64_t diff_sec = next_return_ts - now;
        long long days_left = (diff_sec + 86399) / 86400; 

        seq_printf(m,
            "Венера вернётся в созвездие Стрельца через %lld дней.\n"
            "(Ожидаемая дата: 12 декабря 2027 г.)\n",
            days_left);
    }

    return 0;
}

static int venus_proc_open(struct inode *inode, struct file *file)
{
    return single_open(file, venus_proc_show, NULL);
}

static const struct proc_ops venus_proc_ops = {
    .proc_open    = venus_proc_open,
    .proc_read    = seq_read,
    .proc_lseek   = seq_lseek,
    .proc_release = single_release,
};

static int __init venus_lab_init(void)
{
    if (!proc_create(PROC_NAME, 0444, NULL, &venus_proc_ops))
        return -ENOMEM;

    pr_info("Venus Lab: tracking return to Sagittarius\n");
    return 0;
}

static void __exit venus_lab_exit(void)
{
    remove_proc_entry(PROC_NAME, NULL);
    pr_info("Venus Lab unloaded.\n");
}

module_init(venus_lab_init);
module_exit(venus_lab_exit);
MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("When will Venus return to its current constellation (Sagittarius)?");
