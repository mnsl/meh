import csv

class Entry(object):
    def __init__(self, recipient, hops, pings_sent, acks, avg_latency, battery_level):
        self.recipient = recipient
        self.hops = int(hops)
        self.pings_sent = int(pings_sent)
        self.acks = int(acks)
        self.avg_latency = float(avg_latency)
        self.battery_level = float(battery_level)
    
    def show(self):
        return {'recipient': self.recipient, 
                'hops': self.hops, 
                'pings_sent': self.pings_sent,
                'acks': self.acks,
                'avg_latency': self.avg_latency, 
                'battery_level': self.battery_level }

def get_entry_list(reader, excludeHeader=True):
    entry_list = []
    count = 0
    for row in reader:
        if count != 0:
            entry_list.append(Entry(row[0], row[1], row[2], row[3], row[4], row[5]))
        count += 1
    return entry_list

def index_by_hop_count(entry_list):
    hop_count_dict = {}
    for entry in entry_list:
        if entry.hops in hop_count_dict:
            hop_count_dict[entry.hops].append(entry)
        else:
            hop_count_dict[entry.hops] = [entry]
    return hop_count_dict

def index_by_recipient(entry_list):
    recipient_dict = {}
    for entry in entry_list:
        if entry.recipient in recipient_dict:
            recipient_dict[entry.recipient].append(entry)
        else:
            recipient_dict[entry.recipient] = [entry]
    return recipient_dict

def get_avg_latency(hop_dict):
    user_to_avg = {}
    hop_to_avg = {}

    for hop_count in hop_dict.keys():
        # get list of users who are this hop count away
        recipient_entry_map = index_by_recipient(hop_dict[hop_count])
        for recipient, entries in recipient_entry_map.items():
            # Get the average latency for a specific connection by looking at the last entry
            # for a specific user.
            user_to_avg[recipient] = entries[-1].avg_latency

        # in order to get average latency for the specific hop_count
        # len(entries for specific user)*avg_latency for user
        total_entries_for_hop_count = sum([len(entry_list) for entry_list in recipient_entry_map.values()])
        hop_to_avg[hop_count] = sum([user_to_avg[recipient]*len(recipient_entry_map[recipient])/total_entries_for_hop_count for recipient in recipient_entry_map])

    return (user_to_avg, hop_to_avg)

def get_loss_rate(hop_dict):
    user_to_loss_rate = {}
    hop_to_loss_rate = {}

    for hop_count in hop_dict.keys():
        # get list of users who are this hop count away
        recipient_entry_map = index_by_recipient(hop_dict[hop_count])
        for recipient, entries in recipient_entry_map.items():
            # Get the average latency for a specific connection by looking at the last entry
            # for a specific user.
            user_to_loss_rate[recipient] = 1 - float(entries[-1].acks)/entries[-1].pings_sent

        # in order to get average latency for the specific hop_count
        # len(entries for specific user)*avg_latency for user
        total_entries_for_hop_count = sum([len(entry_list) for entry_list in recipient_entry_map.values()])
        hop_to_loss_rate[hop_count] = sum([user_to_loss_rate[recipient]*len(recipient_entry_map[recipient])/total_entries_for_hop_count for recipient in recipient_entry_map])

    return (user_to_loss_rate, hop_to_loss_rate)

def get_hop_counts(entry_list):
    recipient_dict = index_by_recipient(entry_list)
    hops = {}
    for recipient in recipient_dict:
        hops[recipient] = recipient_dict[recipient][0].hops
    return hops


with open('log.csv', 'rb') as csvfile:
    reader = csv.reader(csvfile)
    entry_list = get_entry_list(reader)
    hop_dict = index_by_hop_count(entry_list)

    # Get average latency 
    user_to_avg, hop_to_avg = get_avg_latency(hop_dict)
    print('user avg latency', user_to_avg)
    print('hop count avg latency', hop_to_avg)
    user_to_loss_rate, hop_to_loss_rate = get_loss_rate(hop_dict)
    print('user loss rate', user_to_loss_rate)
    print('hop loss rate', hop_to_loss_rate)

    # Get map of user to hop count
    print(get_hop_counts(entry_list))



    



