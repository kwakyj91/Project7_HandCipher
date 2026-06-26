import argparse
from pathlib import Path

import torch
import torch.nn as nn
import torch.nn.functional as F
from torch.utils.data import DataLoader, Dataset
from torchvision import datasets, transforms
from tqdm import tqdm

class EmnistDataset(Dataset):
    def __init__(self, root, train=True):
    # EMNIST 이미지는 일반 MNIST와 방향이 다르게 저장되어 있음
    # x.squeeze(0).T 로 글자방향을 맞춘다.
        transform = transforms.Compose([
            transforms.ToTensor(),
            transforms.Lambda(lambda x: x.squeeze(0).T.reshape(1,28,28))
        ])
        self.dataset = datasets.EMNIST(
            root=root,
            split='letters',
            train=train,
            download=True,
            transform=transform,
        )
    def __len__(self):
        return len(self.dataset)
    def __getitem__(self, index):
        image, label = self.dataset[index]
        # EMNIST Letters : A = 1, B = 2 ...Z = 26
        # 학습용 라벨 A = 0 ... Z = 25
        label = label - 1
        return image, label