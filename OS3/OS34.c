#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/printk.h>
#include <linux/proc_fs.h>
#include <linux/seq_file.h>
#include <linux/time.h>
#include <linux/math64.h>

#define PROC_NAME "venus_OSlab"

//oпорная точка: Венера вошла в созвездие стрельца 30 декабря 2025 г. 00:00 UTC

#define VENUS_BASE_TS 1767052800LL

// Синодический период Венеры  ~583.92 суток
#define DAY_SEC 86400LL
#define VENUS_PERIOD_SEC (58392LL * DAY_SEC / 100)

static const char * const month_names[] = {
    "января", "февраля", "марта", "апреля",
    "мая", "июня", "июля", "августа",
    "сентября", "октября", "ноября", "декабря"
};

static time64_t venus_next_return(time64_t now)
{
    time64_t delta, cycles;

    if (now <= VENUS_BASE_TS)
        return VENUS_BASE_TS;

    delta = now - VENUS_BASE_TS;

    cycles = div64_s64(delta + VENUS_PERIOD_SEC - 1,
                       VENUS_PERIOD_SEC);

    return VENUS_BASE_TS + cycles * VENUS_PERIOD_SEC;
}

static int venus_proc_show(struct seq_file *m, void *v)
{
    time64_t now = ktime_get_real_seconds();
    time64_t next_ts = venus_next_return(now);
    struct tm tm;
    long long days_left;

    time64_to_tm(next_ts, 0, &tm);

    if (now >= next_ts) {
        seq_puts(m,
            "Венера сейчас находится в созвездии Стрельца.\n");
        return 0;
    }

    days_left = div64_s64(next_ts - now + DAY_SEC - 1, DAY_SEC);

    seq_printf(m,
        "Венера вернётся в текущее созвездие Стрельца через %lld дней.\n"
        "Предполагаемая дата: %d %s %d г. \n"
        "Расчёт по синодическому периоду Венеры\n",
        days_left,
        tm.tm_mday,
        month_names[tm.tm_mon],
        tm.tm_year + 1900
    );

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

    pr_info("Venus Lab: tracking Venus return \n");
    return 0;
}

static void __exit venus_lab_exit(void)
{
    remove_proc_entry(PROC_NAME, NULL);
    pr_info("Venus OS Lab \n");
}

module_init(venus_lab_init);
module_exit(venus_lab_exit);

MODULE_LICENSE("GPL");
MODULE_AUTHOR("venus_OS_lab");
MODULE_DESCRIPTION("Approximate Venus return to Sagittarius ");
